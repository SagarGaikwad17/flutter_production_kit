import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/repositories/runtime_control_repository.dart';
import 'package:flutter_production_kit/runtime_control/flags/feature_flag_engine.dart';
import 'package:flutter_production_kit/runtime_control/flags/flag_evaluator.dart';
import 'package:flutter_production_kit/runtime_control/kill_switch/emergency_kill_switch.dart';
import 'package:flutter_production_kit/runtime_control/overrides/local_override_manager.dart';
import 'package:flutter_production_kit/runtime_control/policies/runtime_control_policy.dart';
import 'package:flutter_production_kit/runtime_control/policies/stale_config_policy.dart';
import 'package:flutter_production_kit/runtime_control/remote_config/config_cache_manager.dart';
import 'package:flutter_production_kit/runtime_control/remote_config/remote_config_manager.dart';
import 'package:flutter_production_kit/runtime_control/rollout/rollout_engine.dart';
import 'package:flutter_production_kit/runtime_control/sync/config_sync_manager.dart';
import 'package:flutter_production_kit/runtime_control/targeting/user_targeting_engine.dart';
import 'package:flutter_production_kit/runtime_control/tracing/runtime_control_observer.dart';
import 'package:get_it/get_it.dart';

/// Runtime control module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All runtime control dependencies are registered here in one place.
/// - The feature flag engine is a singleton — single evaluation point.
/// - Kill switch is a singleton — shared across all feature checks.
/// - Config sync manager is a singleton — manages periodic config fetch.
/// - Policies are configurable — inject custom policies per environment.
/// - The module integrates with permission system via setEntitlements().
///
/// Usage:
/// ```dart
/// RuntimeControlModule.register(
///   getIt,
///   environment: FlavorConfig.instance.env.name,
///   policy: RuntimeControlPolicy.production,
///   configFetcher: MyBackendConfigFetcher(),
///   configValidator: MyConfigValidator(),
///   repository: MyRuntimeControlRepository(),
/// );
///
/// // Start sync manager after registration:
/// final syncManager = getIt<ConfigSyncManager>();
/// await syncManager.start();
///
/// // Use the feature flag engine:
/// final engine = getIt<FeatureFlagEngine>();
/// final result = await engine.isFeatureEnabled(
///   featureKey: 'new_payment_flow',
///   userId: 'user_123',
///   tenantId: 'tenant_456',
/// );
/// ```
abstract final class RuntimeControlModule {
  RuntimeControlModule._();

  static const String _tag = 'RuntimeControlModule';

  static void register(
    GetIt getIt, {
    required String environment,
    required ConfigFetcher configFetcher,
    required ConfigValidator configValidator,
    required RuntimeControlRepository repository,
    RuntimeControlPolicy? policy,
    StaleConfigPolicy? staleConfigPolicy,
    Duration syncInterval = const Duration(minutes: 15),
    bool autoStartSync = false,
    Map<String, CustomTargetingEvaluator>? customTargetingEvaluators,
  }) {
    AppLogger.info(_tag, 'Registering runtime control module...');

    final effectivePolicy = policy ?? RuntimeControlPolicy.production;
    final effectiveStalePolicy = staleConfigPolicy ?? const StaleConfigPolicy();

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RuntimeControlPolicy>(() => effectivePolicy);
    getIt.registerLazySingleton<StaleConfigPolicy>(() => effectiveStalePolicy);

    // ── Observers ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RuntimeControlObserver>(
      () => RuntimeControlObserver(),
    );

    // ── Evaluators ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<FlagEvaluator>(() => const FlagEvaluator());

    getIt.registerLazySingleton<RolloutEngine>(() => const RolloutEngine());

    getIt.registerLazySingleton<UserTargetingEngine>(
      () => UserTargetingEngine(
        customEvaluators: customTargetingEvaluators,
      ),
    );

    // ── Kill Switch ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<EmergencyKillSwitch>(
      () => EmergencyKillSwitch(
        repository: repository,
      ),
    );

    // ── Cache ────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ConfigCacheManager>(
      () => ConfigCacheManager(
        repository: repository,
      ),
    );

    // ── Remote Config ────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RemoteConfigManager>(
      () => RemoteConfigManager(
        repository: repository,
        fetcher: configFetcher,
        validator: configValidator,
        environment: environment,
      ),
    );

    // ── Sync Manager ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ConfigSyncManager>(
      () => ConfigSyncManager(
        remoteConfigManager: getIt<RemoteConfigManager>(),
        observer: getIt<RuntimeControlObserver>(),
        syncInterval: syncInterval,
      ),
    );

    // ── Local Overrides ──────────────────────────────────────────────────────

    getIt.registerLazySingleton<LocalOverrideManager>(
      () => LocalOverrideManager(
        isProductionMode: effectivePolicy != RuntimeControlPolicy.development,
        allowProductionOverrides: effectivePolicy.allowLocalOverridesInProduction,
      ),
    );

    // ── Feature Flag Engine ──────────────────────────────────────────────────

    getIt.registerLazySingleton<FeatureFlagEngine>(
      () => FeatureFlagEngine(
        repository: repository,
        killSwitch: getIt<EmergencyKillSwitch>(),
        staleConfigPolicy: effectiveStalePolicy,
        observer: getIt<RuntimeControlObserver>(),
        localOverrideManager: getIt<LocalOverrideManager>(),
        flagEvaluator: getIt<FlagEvaluator>(),
        environment: environment,
      ),
    );

    AppLogger.info(_tag, 'Runtime control module registration complete.');

    // Auto-start sync if requested.
    if (autoStartSync) {
      getIt<ConfigSyncManager>().start();
    }
  }

  /// Unregister all runtime control dependencies.
  static void unregister(GetIt getIt) {
    try {
      getIt<ConfigSyncManager>().stop();
    } catch (_) {}

    try {
      getIt<RuntimeControlObserver>().clearListeners();
    } catch (_) {}

    getIt.unregister<FeatureFlagEngine>();
    getIt.unregister<LocalOverrideManager>();
    getIt.unregister<ConfigSyncManager>();
    getIt.unregister<RemoteConfigManager>();
    getIt.unregister<ConfigCacheManager>();
    getIt.unregister<EmergencyKillSwitch>();
    getIt.unregister<UserTargetingEngine>();
    getIt.unregister<RolloutEngine>();
    getIt.unregister<FlagEvaluator>();
    getIt.unregister<RuntimeControlObserver>();
    getIt.unregister<StaleConfigPolicy>();
    getIt.unregister<RuntimeControlPolicy>();

    AppLogger.info(_tag, 'Runtime control module unregistered.');
  }
}
