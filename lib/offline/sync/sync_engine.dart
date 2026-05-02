import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/entities/conflict_record.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_status.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_trace.dart';
import 'package:flutter_production_kit/offline/domain/repositories/sync_repository.dart';
import 'package:flutter_production_kit/offline/queue/offline_queue_manager.dart';
import 'package:flutter_production_kit/offline/sync/retry_scheduler.dart';
import 'package:flutter_production_kit/offline/sync/sync_orchestrator.dart';
import 'package:flutter_production_kit/offline/network/connectivity_observer.dart';
import 'package:flutter_production_kit/offline/conflicts/conflict_resolver.dart';
import 'package:flutter_production_kit/offline/policies/sync_priority_policy.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/offline/tracing/sync_observer.dart';

/// Sync engine — central orchestrator for offline sync operations.
///
/// Design rationale:
/// - Coordinates between queue, network, conflicts, permissions, and recovery.
/// - Manages the sync lifecycle: idle → syncing → complete/error.
/// - Handles network flapping gracefully (pause/resume with stability window).
/// - Processes operations in priority-ordered chunks.
/// - Revalidates permissions at sync time (not just enqueue time).
/// - Detects and routes conflicts to the resolver.
/// - Saves checkpoints for crash recovery.
/// - Emits events for UI monitoring.
///
/// Sync flow:
/// 1. Check connectivity — wait if unstable.
/// 2. Revalidate permissions — reject ops for users who lost access.
/// 3. Check idempotency — skip already-synced operations.
/// 4. Process operations in chunks (critical first).
/// 5. Detect conflicts — route to resolver.
/// 6. Save checkpoint periodically.
/// 7. Handle failures — retry or poison.
/// 8. Complete session — emit summary.
class SyncEngine {
  SyncEngine({
    required OfflineQueueManager queueManager,
    required SyncRepository repository,
    required SyncOrchestrator orchestrator,
    required ConnectivityObserver connectivityObserver,
    required ConflictResolver conflictResolver,
    required RetryScheduler retryScheduler,
    required PermissionEngine permissionEngine,
    required SyncObserver observer,
    SyncPriorityPolicy? priorityPolicy,
    this.syncInterval = const Duration(minutes: 5),
    this.checkpointInterval = 50,
    this.maxOperationsPerSession = 200,
    this.permissionRevalidationEnabled = true,
  })  : _queueManager = queueManager,
        _repository = repository,
        _orchestrator = orchestrator,
        _connectivityObserver = connectivityObserver,
        _conflictResolver = conflictResolver,
        _retryScheduler = retryScheduler,
        _permissionEngine = permissionEngine,
        _observer = observer,
        _priorityPolicy = priorityPolicy ?? const SyncPriorityPolicy();

  static const String _tag = 'SyncEngine';

  final OfflineQueueManager _queueManager;
  final SyncRepository _repository;
  final SyncOrchestrator _orchestrator;
  final ConnectivityObserver _connectivityObserver;
  final ConflictResolver _conflictResolver;
  // ignore: unused_field
  final RetryScheduler _retryScheduler;
  // ignore: unused_field
  final PermissionEngine _permissionEngine;
  final SyncObserver _observer;
  // ignore: unused_field
  final SyncPriorityPolicy _priorityPolicy;

  final Duration syncInterval;
  final int checkpointInterval;
  final int maxOperationsPerSession;
  final bool permissionRevalidationEnabled;

  SyncEngineState _state = SyncEngineState.stopped;
  String? _currentUserId;
  String? _currentSessionId;
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;

  SyncEngineState get state => _state;
  bool get isRunning => _state == SyncEngineState.running;
  bool get isPaused => _state == SyncEngineState.paused;

  /// Start the sync engine with the current user context.
  Future<void> start({
    required String userId,
    bool autoSync = true,
  }) async {
    if (_state == SyncEngineState.running) {
      AppLogger.info(_tag, 'Sync engine already running.');
      return;
    }

    _currentUserId = userId;
    _currentSessionId = 'sync_${DateTime.now().millisecondsSinceEpoch}';
    _state = SyncEngineState.initialized;

    AppLogger.info(_tag, 'Sync engine started for user: $userId');

    // Check for recovery from a previous session.
    await _checkRecovery();

    // Start auto-sync timer.
    if (autoSync) {
      _startAutoSync();
    }

    // Listen for connectivity changes.
    _connectivitySubscription =
        _connectivityObserver.stateStream.listen(_onConnectivityChange);

    _state = SyncEngineState.running;
    _observer.onEngineStateChange(SyncEngineState.running);
  }

  /// Pause sync — stops auto-sync but preserves the queue.
  void pause() {
    if (_state != SyncEngineState.running) return;

    _syncTimer?.cancel();
    _state = SyncEngineState.paused;

    AppLogger.info(_tag, 'Sync engine paused.');
    _observer.onEngineStateChange(SyncEngineState.paused);
  }

  /// Resume sync after pause.
  void resume() {
    if (_state != SyncEngineState.paused) return;

    _startAutoSync();
    _state = SyncEngineState.running;

    AppLogger.info(_tag, 'Sync engine resumed.');
    _observer.onEngineStateChange(SyncEngineState.running);
  }

  /// Stop the sync engine — cancels all timers and subscriptions.
  Future<void> stop() async {
    _syncTimer?.cancel();
    await _connectivitySubscription?.cancel();

    _state = SyncEngineState.stopped;
    AppLogger.info(_tag, 'Sync engine stopped.');
    _observer.onEngineStateChange(SyncEngineState.stopped);
  }

  /// Trigger an immediate sync session.
  Future<SyncSessionSummary?> triggerSync() async {
    if (!_connectivityObserver.isConnected) {
      AppLogger.info(_tag, 'Cannot sync — no network connection.');
      return null;
    }

    if (!_connectivityObserver.isStable) {
      AppLogger.info(_tag, 'Cannot sync — network is unstable.');
      return null;
    }

    if (_state == SyncEngineState.running ||
        _state == SyncEngineState.recovering) {
      return _runSyncSession();
    }

    AppLogger.warning(_tag, 'Cannot trigger sync — engine is in state: $_state');
    return null;
  }

  /// Execute a single sync session.
  Future<SyncSessionSummary?> _runSyncSession() async {
    if (_currentUserId == null) return null;

    _state = SyncEngineState.running;
    _queueManager.resetDrainingCount();

    final sessionId = _currentSessionId!;
    final startedAt = DateTime.now();

    AppLogger.info(_tag, 'Starting sync session: $sessionId');
    _observer.onSessionStart(sessionId);

    var totalProcessed = 0;
    var successful = 0;
    var failed = 0;
    var conflicts = 0;
    var duplicates = 0;
    var poisoned = 0;

    try {
      while (totalProcessed < maxOperationsPerSession) {
        // Get next batch.
        final batch = await _queueManager.dequeue();
        if (batch.isEmpty) break;

        // Process each operation.
        for (final operation in batch) {
          try {
            final result = await _processOperation(operation);

            switch (result.type) {
              case SyncResultType.success:
                await _queueManager.complete(
                  operation.id,
                  serverVersion: result.serverVersion,
                );
                successful++;
                break;
              case SyncResultType.duplicate:
                await _queueManager.complete(operation.id);
                duplicates++;
                break;
              case SyncResultType.conflict:
                conflicts++;
                final conflict = result.conflict;
                if (conflict != null) {
                  await _repository.storeConflict(conflict);
                }
                await _queueManager.fail(
                  operation.id,
                  error: 'Conflict detected',
                );
                break;
              case SyncResultType.permissionDenied:
                poisoned++;
                await _queueManager.poison(
                  operation.id,
                  reason: 'Permission denied at sync time',
                );
                break;
              case SyncResultType.failed:
                failed++;
                await _queueManager.fail(
                  operation.id,
                  error: result.error,
                );
                break;
              case SyncResultType.poisoned:
                poisoned++;
                await _queueManager.poison(
                  operation.id,
                  reason: result.error,
                );
                break;
            }
          } catch (e) {
            failed++;
            await _queueManager.fail(operation.id, error: e.toString());
            AppLogger.error(_tag, 'Operation processing crashed', error: e);
          }

          totalProcessed++;

          // Save checkpoint periodically.
          if (totalProcessed % checkpointInterval == 0) {
            await _repository.saveCheckpoint(
              sessionId: sessionId,
              operationsProcessed: totalProcessed,
              totalOperations: totalProcessed,
            );
          }
        }
      }

      final summary = SyncSessionSummary(
        sessionId: sessionId,
        startedAt: startedAt,
        endedAt: DateTime.now(),
        totalOperations: totalProcessed,
        successful: successful,
        failed: failed,
        conflicts: conflicts,
        duplicates: duplicates,
        poisoned: poisoned,
      );

      AppLogger.info(
        _tag,
        'Sync session complete: $summary',
      );

      _observer.onSessionComplete(summary);
      return summary;
    } catch (e, st) {
      AppLogger.error(_tag, 'Sync session crashed', error: e, stackTrace: st);

      // Save checkpoint on crash.
      await _repository.saveCheckpoint(
        sessionId: sessionId,
        operationsProcessed: totalProcessed,
        totalOperations: totalProcessed,
      );

      _observer.onSessionError(sessionId, e.toString());
      return null;
    }
  }

  /// Process a single operation through the sync pipeline.
  Future<SyncResult> _processOperation(SyncOperation operation) async {
    final traces = <SyncTraceEntry>[];

    try {
      // Step 1: Permission revalidation.
      if (permissionRevalidationEnabled && _currentUserId != null) {
        final permissionResult = _permissionEngine.check(
          userId: _currentUserId!,
          action: _mapActionToPermission(operation.action),
          resource: operation.resourceType,
          resourceId: operation.resourceId,
          branchId: operation.branchId,
          tenantId: operation.tenantId,
          isOnline: true,
        );

        if (!permissionResult.isAllowed) {
          return SyncResult(
            type: SyncResultType.permissionDenied,
            error: 'Permission denied: ${permissionResult.runtimeType}',
          );
        }
      }

      // Step 2: Idempotency check.
      if (operation.idempotencyKey != null) {
        final existingId =
            await _repository.getIdempotencyResult(operation.idempotencyKey!);
        if (existingId != null && existingId != operation.id) {
          return SyncResult(
            type: SyncResultType.duplicate,
            error: 'Duplicate operation — already synced as $existingId',
          );
        }
      }

      // Step 3: Execute the operation.
      final response = await _orchestrator.execute(operation);

      // Step 4: Check for conflicts in the response.
      if (response.hasConflict) {
        final conflict = ConflictRecord(
          id: 'conflict_${DateTime.now().millisecondsSinceEpoch}',
          resourceType: operation.resourceType,
          resourceId: operation.resourceId,
          localVersion: operation.payload,
          serverVersion: response.serverPayload ?? {},
          localOperationId: operation.id,
          detectedAt: DateTime.now(),
        );

        // Try to auto-resolve.
        final resolution = _conflictResolver.resolve(
          conflict: conflict,
          serverPayload: response.serverPayload,
        );

        if (resolution.requiresManual) {
          return SyncResult(
            type: SyncResultType.conflict,
            conflict: conflict,
            error: 'Manual resolution required',
          );
        }

        // Auto-resolved — re-sync with merged payload.
        final retryResponse = await _orchestrator.execute(
          operation.copyWith(payload: resolution.resolvedPayload!),
        );

        await _storeIdempotency(operation);
        return SyncResult(
          type: SyncResultType.success,
          serverVersion: retryResponse.serverVersion,
        );
      }

      // Step 5: Success — store idempotency key.
      await _storeIdempotency(operation);

      traces.add(SyncTraceEntry(
        id: 'trace_${DateTime.now().millisecondsSinceEpoch}',
        operationId: operation.id,
        phase: SyncTracePhase.completed,
        timestamp: DateTime.now(),
        success: true,
      ));

      return SyncResult(
        type: SyncResultType.success,
        serverVersion: response.serverVersion,
      );
    } catch (e) {
      return SyncResult(
        type: SyncResultType.failed,
        error: e.toString(),
      );
    } finally {
      if (traces.isNotEmpty) {
        await _repository.storeTraceEntries(traces);
      }
    }
  }

  String _mapActionToPermission(SyncAction action) {
    return switch (action) {
      SyncAction.create => 'create',
      SyncAction.update => 'update',
      SyncAction.delete => 'delete',
      SyncAction.replace => 'update',
    };
  }

  Future<void> _storeIdempotency(SyncOperation operation) async {
    if (operation.idempotencyKey != null) {
      await _repository.storeIdempotencyResult(
        idempotencyKey: operation.idempotencyKey!,
        operationId: operation.id,
        syncedAt: DateTime.now(),
      );
    }
  }

  Future<void> _checkRecovery() async {
    final checkpoint = await _repository.getLastCheckpoint();
    if (checkpoint != null && checkpoint.progress < 1.0) {
      AppLogger.info(
        _tag,
        'Found incomplete checkpoint: ${checkpoint.sessionId} '
        '(${checkpoint.operationsProcessed}/${checkpoint.totalOperations})',
      );

      _state = SyncEngineState.recovering;
      _observer.onRecoveryStart(checkpoint.sessionId);

      // Recovery is handled by the next sync session.
      // The queue still has the uncompleted operations.
      await _repository.clearCheckpoints();

      _state = SyncEngineState.initialized;
      _observer.onRecoveryComplete(
        checkpoint.sessionId,
        checkpoint.operationsProcessed,
      );
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) {
      if (_connectivityObserver.isConnected &&
          _connectivityObserver.isStable) {
        triggerSync();
      }
    });
  }

  void _onConnectivityChange(NetworkState state) {
    if (state == NetworkState.connected && _connectivityObserver.isStable) {
      if (_state == SyncEngineState.paused) {
        resume();
      }
      triggerSync();
    } else if (state == NetworkState.disconnected) {
      pause();
    }
  }

  void dispose() {
    stop();
    _connectivitySubscription?.cancel();
  }
}

/// Result of processing a sync operation.
class SyncResult {
  const SyncResult({
    required this.type,
    this.serverVersion,
    this.conflict,
    this.error,
  });

  final SyncResultType type;
  final String? serverVersion;
  final ConflictRecord? conflict;
  final String? error;
}

enum SyncResultType {
  success,
  duplicate,
  conflict,
  permissionDenied,
  failed,
  poisoned,
}
