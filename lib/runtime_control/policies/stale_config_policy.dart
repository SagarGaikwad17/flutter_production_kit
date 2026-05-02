import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';

/// Stale config policy — controls config freshness and staleness rejection.
///
/// Design rationale:
/// - Config has a TTL (time-to-live) — after which it's considered stale.
/// - Stale configs are rejected for sensitive operations.
/// - [maxAge] is the maximum age before config is rejected.
/// - [softMaxAge] is the age at which warnings are emitted (before rejection).
/// - [allowStaleForSafeOperations] permits some operations with stale config.
///
/// This prevents dangerous behavior from outdated config:
/// - Old kill switches that should be active might be missing.
/// - Old entitlements might grant access that should be revoked.
/// - Old rollout rules might include/exclude the wrong users.
class StaleConfigPolicy {
  const StaleConfigPolicy({
    this.maxAge = const Duration(hours: 24),
    this.softMaxAge = const Duration(hours: 12),
    this.allowStaleForSafeOperations = true,
    this.requireFreshForKillSwitch = true,
    this.requireFreshForEntitlements = true,
  });

  final Duration maxAge;
  final Duration softMaxAge;
  final bool allowStaleForSafeOperations;
  final bool requireFreshForKillSwitch;
  final bool requireFreshForEntitlements;

  /// Check if a config is still valid (not stale).
  bool isConfigValid(RuntimeConfig config) {
    final age = getConfigAge(config);
    return age <= maxAge;
  }

  /// Check if a config is approaching staleness (soft warning zone).
  bool isConfigApproachingStale(RuntimeConfig config) {
    final age = getConfigAge(config);
    return age > softMaxAge && age <= maxAge;
  }

  /// Get the age of a config.
  Duration getConfigAge(RuntimeConfig config) {
    return DateTime.now().difference(config.fetchedAt);
  }

  /// Check if fresh config is required for the given operation type.
  bool requiresFreshConfig(RuntimeControlOperationType operationType) {
    return switch (operationType) {
      RuntimeControlOperationType.killSwitchCheck => requireFreshForKillSwitch,
      RuntimeControlOperationType.entitlementCheck => requireFreshForEntitlements,
      RuntimeControlOperationType.featureCheck => false,
      RuntimeControlOperationType.rolloutCheck => false,
      RuntimeControlOperationType.configValue => allowStaleForSafeOperations,
    };
  }

  /// Default policy for production apps — strict staleness controls.
  static const StaleConfigPolicy strict = StaleConfigPolicy(
    maxAge: Duration(hours: 12),
    softMaxAge: Duration(hours: 6),
    allowStaleForSafeOperations: false,
    requireFreshForKillSwitch: true,
    requireFreshForEntitlements: true,
  );

  /// Default policy for development apps — lenient staleness controls.
  static const StaleConfigPolicy lenient = StaleConfigPolicy(
    maxAge: Duration(hours: 48),
    softMaxAge: Duration(hours: 24),
    allowStaleForSafeOperations: true,
    requireFreshForKillSwitch: false,
    requireFreshForEntitlements: false,
  );
}

enum RuntimeControlOperationType {
  killSwitchCheck,
  entitlementCheck,
  featureCheck,
  rolloutCheck,
  configValue,
}
