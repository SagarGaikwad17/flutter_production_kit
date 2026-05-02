import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/conflicts/conflict_resolver.dart';
import 'package:flutter_production_kit/offline/conflicts/resolution_strategies.dart';
import 'package:flutter_production_kit/offline/domain/repositories/sync_repository.dart';
import 'package:flutter_production_kit/offline/guards/offline_action_guard.dart';
import 'package:flutter_production_kit/offline/network/connectivity_observer.dart';
import 'package:flutter_production_kit/offline/persistence/in_memory_sync_store.dart';
import 'package:flutter_production_kit/offline/policies/idempotency_policy.dart';
import 'package:flutter_production_kit/offline/policies/offline_action_policy.dart';
import 'package:flutter_production_kit/offline/policies/retry_backoff_policy.dart';
import 'package:flutter_production_kit/offline/policies/sync_priority_policy.dart';
import 'package:flutter_production_kit/offline/queue/offline_queue_manager.dart';
import 'package:flutter_production_kit/offline/recovery/sync_recovery_manager.dart';
import 'package:flutter_production_kit/offline/sync/retry_scheduler.dart';
import 'package:flutter_production_kit/offline/sync/sync_engine.dart';
import 'package:flutter_production_kit/offline/sync/sync_orchestrator.dart';
import 'package:flutter_production_kit/offline/tracing/sync_observer.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:get_it/get_it.dart';

/// Offline sync module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All offline sync dependencies are registered here in one place.
/// - The sync store is a singleton — single source of truth for queue state.
/// - The sync engine is a singleton — single orchestrator for all sync sessions.
/// - Policies are configurable — inject custom policies for different app types.
/// - The module integrates with the permission engine for sync-time revalidation.
///
/// Usage:
/// ```dart
/// OfflineSyncModule.register(
///   getIt,
///   permissionEngine: getIt<PermissionEngine>(),
///   offlineActionPolicy: OfflineActionPolicy.healthcare,
///   executor: MyBackendSyncExecutor(),
/// );
///
/// // Later in code:
/// final engine = getIt<SyncEngine>();
/// await engine.start(userId: 'user_123');
/// ```
abstract final class OfflineSyncModule {
  OfflineSyncModule._();

  static const String _tag = 'OfflineSyncModule';

  static void register(
    GetIt getIt, {
    required PermissionEngine permissionEngine,
    required SyncOperationExecutor executor,
    OfflineActionPolicy? offlineActionPolicy,
    SyncPriorityPolicy? priorityPolicy,
    RetryBackoffPolicy? retryBackoffPolicy,
    IdempotencyPolicy? idempotencyPolicy,
    Duration syncInterval = const Duration(minutes: 5),
    int maxOperationsPerSession = 200,
    int maxPendingOperations = 5000,
    bool autoStart = false,
    String? initialUserId,
  }) {
    AppLogger.info(_tag, 'Registering offline sync module...');

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<OfflineActionPolicy>(
      () => offlineActionPolicy ?? OfflineActionPolicy.healthcare,
    );

    getIt.registerLazySingleton<SyncPriorityPolicy>(
      () => priorityPolicy ?? const SyncPriorityPolicy(),
    );

    getIt.registerLazySingleton<RetryBackoffPolicy>(
      () => retryBackoffPolicy ?? const RetryBackoffPolicy(),
    );

    getIt.registerLazySingleton<IdempotencyPolicy>(
      () => idempotencyPolicy ?? const IdempotencyPolicy(),
    );

    // ── Network ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ConnectivityObserver>(
      () => ConnectivityObserver(),
    );

    // ── Persistence ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SyncRepository>(
      () => InMemorySyncStore(),
    );

    // ── Conflict Resolution ──────────────────────────────────────────────────

    getIt.registerLazySingleton<ConflictResolver>(
      () => ConflictResolver(
        strategies: const ResolutionStrategies(),
      ),
    );

    // ── Queue ────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<OfflineQueueManager>(
      () => OfflineQueueManager(
        repository: getIt<SyncRepository>(),
        priorityPolicy: getIt<SyncPriorityPolicy>(),
        maxPendingOperations: maxPendingOperations,
      ),
    );

    // ── Sync Components ──────────────────────────────────────────────────────

    getIt.registerLazySingleton<SyncOrchestrator>(
      () => SyncOrchestrator(executor: executor),
    );

    getIt.registerLazySingleton<SyncObserver>(
      () => SyncObserver(),
    );

    getIt.registerLazySingleton<RetryScheduler>(
      () => RetryScheduler(
        repository: getIt<SyncRepository>(),
        connectivityObserver: getIt<ConnectivityObserver>(),
        backoffPolicy: getIt<RetryBackoffPolicy>(),
      ),
    );

    getIt.registerLazySingleton<SyncRecoveryManager>(
      () => SyncRecoveryManager(
        repository: getIt<SyncRepository>(),
        queueManager: getIt<OfflineQueueManager>(),
      ),
    );

    // ── Engine ───────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        queueManager: getIt<OfflineQueueManager>(),
        repository: getIt<SyncRepository>(),
        orchestrator: getIt<SyncOrchestrator>(),
        connectivityObserver: getIt<ConnectivityObserver>(),
        conflictResolver: getIt<ConflictResolver>(),
        retryScheduler: getIt<RetryScheduler>(),
        permissionEngine: permissionEngine,
        observer: getIt<SyncObserver>(),
        priorityPolicy: getIt<SyncPriorityPolicy>(),
        syncInterval: syncInterval,
        maxOperationsPerSession: maxOperationsPerSession,
      ),
    );

    // ── Guards ───────────────────────────────────────────────────────────────

    getIt.registerFactory<OfflineActionGuard>(
      () => OfflineActionGuard(
        actionPolicy: getIt<OfflineActionPolicy>(),
        permissionEngine: permissionEngine,
      ),
    );

    AppLogger.info(_tag, 'Offline sync module registration complete.');
  }

  /// Unregister all offline sync dependencies.
  static void unregister(GetIt getIt) {
    try {
      getIt<SyncEngine>().dispose();
    } catch (_) {}

    try {
      getIt<SyncObserver>().clearListeners();
    } catch (_) {}

    try {
      getIt<ConnectivityObserver>().dispose();
    } catch (_) {}

    try {
      getIt<RetryScheduler>().dispose();
    } catch (_) {}

    getIt.unregister<OfflineActionGuard>();
    getIt.unregister<SyncEngine>();
    getIt.unregister<SyncRecoveryManager>();
    getIt.unregister<RetryScheduler>();
    getIt.unregister<SyncObserver>();
    getIt.unregister<SyncOrchestrator>();
    getIt.unregister<OfflineQueueManager>();
    getIt.unregister<ConflictResolver>();
    getIt.unregister<SyncRepository>();
    getIt.unregister<ConnectivityObserver>();
    getIt.unregister<IdempotencyPolicy>();
    getIt.unregister<RetryBackoffPolicy>();
    getIt.unregister<SyncPriorityPolicy>();
    getIt.unregister<OfflineActionPolicy>();

    AppLogger.info(_tag, 'Offline sync module unregistered.');
  }
}
