/// Runtime control policy — global rules for runtime control behavior.
///
/// Design rationale:
/// - Controls evaluation order between permissions and feature flags.
/// - Defines which operations require fresh config.
/// - Configures fallback behavior for different scenarios.
/// - Enables/disables local overrides by environment.
///
/// Evaluation order:
/// 1. Kill switch (always first, cannot be overridden)
/// 2. Feature flag check (with targeting, rollout, entitlements)
/// 3. Permission check (if [checkPermissionsAfterFlags] is true)
///
/// This ensures:
/// - Kill switches can instantly block anything.
/// - Feature flags gate feature availability.
/// - Permissions gate user authorization.
/// - Both must pass for access to be granted.
class RuntimeControlPolicy {
  const RuntimeControlPolicy({
    this.evaluationOrder = ControlEvaluationOrder.killSwitchFirst,
    this.checkPermissionsAfterFlags = true,
    this.allowLocalOverridesInProduction = false,
    this.requireFreshConfigForKillSwitch = true,
    this.requireFreshConfigForEntitlements = true,
    this.fallbackBehavior = FallbackBehavior.useCachedConfig,
    this.maxStaleConfigAge = const Duration(hours: 24),
    this.defaultRolloutPercentage = 100,
  });

  final ControlEvaluationOrder evaluationOrder;
  final bool checkPermissionsAfterFlags;
  final bool allowLocalOverridesInProduction;
  final bool requireFreshConfigForKillSwitch;
  final bool requireFreshConfigForEntitlements;
  final FallbackBehavior fallbackBehavior;
  final Duration maxStaleConfigAge;
  final int defaultRolloutPercentage;

  /// Production policy — strict controls, no local overrides.
  static const RuntimeControlPolicy production = RuntimeControlPolicy(
    evaluationOrder: ControlEvaluationOrder.killSwitchFirst,
    checkPermissionsAfterFlags: true,
    allowLocalOverridesInProduction: false,
    requireFreshConfigForKillSwitch: true,
    requireFreshConfigForEntitlements: true,
    fallbackBehavior: FallbackBehavior.useCachedConfig,
  );

  /// Development policy — lenient controls, local overrides allowed.
  static const RuntimeControlPolicy development = RuntimeControlPolicy(
    evaluationOrder: ControlEvaluationOrder.killSwitchFirst,
    checkPermissionsAfterFlags: false,
    allowLocalOverridesInProduction: true,
    requireFreshConfigForKillSwitch: false,
    requireFreshConfigForEntitlements: false,
    fallbackBehavior: FallbackBehavior.useDefaults,
  );
}

enum ControlEvaluationOrder {
  killSwitchFirst,
  flagsFirst,
}

enum FallbackBehavior {
  useCachedConfig,
  useDefaults,
  denyAll,
}
