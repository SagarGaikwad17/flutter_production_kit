import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/feature_evaluation_result.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/feature_flag.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';
import 'package:flutter_production_kit/runtime_control/domain/repositories/runtime_control_repository.dart';
import 'package:flutter_production_kit/runtime_control/flags/flag_evaluator.dart';
import 'package:flutter_production_kit/runtime_control/kill_switch/emergency_kill_switch.dart';
import 'package:flutter_production_kit/runtime_control/overrides/local_override_manager.dart';
import 'package:flutter_production_kit/runtime_control/policies/stale_config_policy.dart';
import 'package:flutter_production_kit/runtime_control/tracing/runtime_control_observer.dart';

/// Feature flag engine — central evaluation point for all feature flags.
///
/// Design rationale:
/// - Single evaluation point for ALL feature flag checks.
/// - Coordinates between:
///   - FlagEvaluator (pure evaluation logic)
///   - EmergencyKillSwitch (emergency disable)
///   - LocalOverrideManager (dev/QA overrides)
///   - StaleConfigPolicy (config freshness)
///   - RuntimeControlObserver (observability)
/// - Evaluation order:
///   1. Local override (dev/QA only — rejected in production)
///   2. Kill switch check (always evaluated, cannot be overridden)
///   3. Stale config check (rejects dangerous stale configs)
///   4. Flag evaluation (targeting, rollout, entitlements, etc.)
/// - Returns typed FeatureEvaluationResult — never a bool.
/// - All evaluations are traced for observability.
class FeatureFlagEngine {
  FeatureFlagEngine({
    required RuntimeControlRepository repository,
    required EmergencyKillSwitch killSwitch,
    required StaleConfigPolicy staleConfigPolicy,
    required RuntimeControlObserver observer,
    LocalOverrideManager? localOverrideManager,
    FlagEvaluator? flagEvaluator,
    this.environment = 'production',
  })  : _repository = repository,
        _killSwitch = killSwitch,
        _staleConfigPolicy = staleConfigPolicy,
        _observer = observer,
        _localOverrideManager = localOverrideManager,
        _flagEvaluator = flagEvaluator ?? const FlagEvaluator();

  static const String _tag = 'FeatureFlagEngine';

  final RuntimeControlRepository _repository;
  final EmergencyKillSwitch _killSwitch;
  final StaleConfigPolicy _staleConfigPolicy;
  final RuntimeControlObserver _observer;
  final LocalOverrideManager? _localOverrideManager;
  final FlagEvaluator _flagEvaluator;
  final String environment;

  RuntimeConfig? _activeConfig;
  Set<String>? _cachedEntitlements;

  /// Set the active runtime config — called after config sync.
  void setActiveConfig(RuntimeConfig config) {
    _activeConfig = config;
    _observer.onConfigLoaded(config.version, config.environment);
    AppLogger.info(
      _tag,
      'Active config set: version ${config.version}, '
      '${config.featureFlags.length} flags, '
      '${config.killSwitches.length} kill switches',
    );
  }

  /// Set user entitlements for subscription-aware checks.
  void setEntitlements(Set<String> entitlements) {
    _cachedEntitlements = entitlements;
  }

  /// Get the active config version.
  int? get activeConfigVersion => _activeConfig?.version;

  /// Check if a feature is enabled for the current user/context.
  ///
  /// This is the PRIMARY entry point for all feature flag checks.
  Future<FeatureEvaluationResult> isFeatureEnabled({
    required String featureKey,
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
    String? region,
    List<String>? roles,
    Set<String>? entitlements,
    String? appVersion,
  }) async {
    // Step 1: Local override (dev/QA only).
    final localOverride = _localOverrideManager?.getOverride(featureKey);
    if (localOverride != null) {
      AppLogger.debug(_tag, 'Local override for "$featureKey": ${localOverride.enabled}');
      _observer.onLocalOverrideUsed(featureKey, localOverride.enabled);
      if (localOverride.enabled) {
        return FeatureEnabled(
          featureKey: featureKey,
          reason: 'Local override enabled.',
        );
      }
    }

    // Step 2: Kill switch check.
    final killSwitchActive = await _killSwitch.isActive(
      featureKey: featureKey,
    );
    if (killSwitchActive.active) {
      final result = FeatureDisabledKillSwitch(
        featureKey: featureKey,
        killSwitchKey: killSwitchActive.key,
        reason: killSwitchActive.reason,
        activatedBy: killSwitchActive.activatedBy,
      );
      _observer.onKillSwitchEvaluated(featureKey, true);
      return result;
    }

    // Step 3: Stale config check.
    final config = _activeConfig;
    if (config == null) {
      // Try fallback to last known good config.
      final fallback = await _repository.getLastKnownGoodConfig();
      if (fallback == null) {
        final result = FeatureEvaluationError(
          featureKey: featureKey,
          error: 'No active config and no fallback available.',
        );
        _observer.onEvaluationError(featureKey, 'no_config');
        return result;
      }
      _activeConfig = fallback;
    }

    if (!_staleConfigPolicy.isConfigValid(_activeConfig!)) {
      final result = FeatureDisabledStaleConfig(
        featureKey: featureKey,
        configAge: _staleConfigPolicy.getConfigAge(_activeConfig!),
        reason: 'Config is stale — ${_staleConfigPolicy.maxAge} max age.',
      );
      _observer.onStaleConfigRejected(featureKey);
      return result;
    }

    // Step 4: Get the flag.
    final flag = _activeConfig!.featureFlags[featureKey];
    if (flag == null) {
      final result = FeatureDisabled(
        featureKey: featureKey,
        reason: 'Feature flag not found in config.',
      );
      _observer.onFlagNotFound(featureKey);
      return result;
    }

    // Step 5: Evaluate the flag.
    final effectiveEntitlements = entitlements ?? _cachedEntitlements;

    final result = _flagEvaluator.evaluate(
      flag: _mergeFlagWithConfig(flag, featureKey),
      userId: userId,
      tenantId: tenantId,
      branchId: branchId,
      whiteLabelClient: whiteLabelClient,
      region: region,
      roles: roles,
      entitlements: effectiveEntitlements,
      appVersion: appVersion,
      killSwitchActive: killSwitchActive.active,
      killSwitchReason: killSwitchActive.reason,
    );

    _observer.onFeatureEvaluated(
      featureKey: featureKey,
      result: result,
      userId: userId,
    );

    return result;
  }

  /// Quick boolean check — for simple use cases.
  /// Prefer [isFeatureEnabled] when you need the disable reason.
  Future<bool> isEnabled({
    required String featureKey,
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
  }) async {
    return isFeatureEnabled(
      featureKey: featureKey,
      userId: userId,
      tenantId: tenantId,
      branchId: branchId,
      whiteLabelClient: whiteLabelClient,
    ).then((result) => result.isEnabled);
  }

  /// Get all features that are enabled for a user.
  Future<List<String>> getEnabledFeatures({
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
  }) async {
    final config = _activeConfig;
    if (config == null) return [];

    final enabled = <String>[];
    for (final key in config.featureFlags.keys) {
      final result = await isFeatureEnabled(
        featureKey: key,
        userId: userId,
        tenantId: tenantId,
        branchId: branchId,
        whiteLabelClient: whiteLabelClient,
      );
      if (result.isEnabled) {
        enabled.add(key);
      }
    }
    return enabled;
  }

  FeatureFlag _mergeFlagWithConfig(FeatureFlagConfig config, String key) {
    // Convert config representation to full FeatureFlag for evaluation.
    return FeatureFlag(
      key: config.key,
      enabled: config.enabled,
      rolloutPercentage: config.rolloutPercentage,
      requiredEntitlements: config.requiredEntitlements,
      allowedTenants: config.allowedTenants,
      blockedTenants: config.blockedTenants,
      allowedWhiteLabels: config.allowedWhiteLabels,
      blockedWhiteLabels: config.blockedWhiteLabels,
      targetingRules: [],
      evaluationOrder: EvaluationOrder.targetingFirst,
    );
  }
}
