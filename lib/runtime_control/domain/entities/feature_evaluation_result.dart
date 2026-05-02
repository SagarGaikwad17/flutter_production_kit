/// Sealed feature evaluation result hierarchy.
///
/// Design rationale:
/// Every feature flag evaluation returns a typed result — never a simple bool.
/// This forces call sites to handle each disable reason explicitly.
/// The result carries enough context for the UI to show the correct message
/// and for the engine to log the appropriate event.
sealed class FeatureEvaluationResult {
  const FeatureEvaluationResult();

  bool get isEnabled => this is FeatureEnabled;
  bool get isDisabled => this is! FeatureEnabled;
}

/// Feature is enabled for this user/context.
final class FeatureEnabled extends FeatureEvaluationResult {
  const FeatureEnabled({
    required this.featureKey,
    this.reason,
    this.viaTargetingRule,
    this.rolloutAssigned = true,
  });

  final String featureKey;
  final String? reason;
  final String? viaTargetingRule;
  final bool rolloutAssigned;
}

/// Feature is disabled — generic.
final class FeatureDisabled extends FeatureEvaluationResult {
  const FeatureDisabled({
    required this.featureKey,
    required this.reason,
  });

  final String featureKey;
  final String reason;
}

/// Feature is disabled by emergency kill switch.
final class FeatureDisabledKillSwitch extends FeatureEvaluationResult {
  const FeatureDisabledKillSwitch({
    required this.featureKey,
    required this.killSwitchKey,
    this.reason,
    this.activatedBy,
  });

  final String featureKey;
  final String killSwitchKey;
  final String? reason;
  final String? activatedBy;
}

/// Feature is disabled by subscription entitlement.
final class FeatureDisabledEntitlement extends FeatureEvaluationResult {
  const FeatureDisabledEntitlement({
    required this.featureKey,
    required this.requiredEntitlements,
    this.currentTier,
    this.reason,
  });

  final String featureKey;
  final List<String> requiredEntitlements;
  final String? currentTier;
  final String? reason;
}

/// Feature is disabled by stale config rejection.
final class FeatureDisabledStaleConfig extends FeatureEvaluationResult {
  const FeatureDisabledStaleConfig({
    required this.featureKey,
    required this.configAge,
    this.reason,
  });

  final String featureKey;
  final Duration configAge;
  final String? reason;
}

/// Feature is disabled by tenant restriction.
final class FeatureDisabledTenantRestricted extends FeatureEvaluationResult {
  const FeatureDisabledTenantRestricted({
    required this.featureKey,
    required this.tenantId,
    this.reason,
  });

  final String featureKey;
  final String tenantId;
  final String? reason;
}

/// Feature is disabled by rollout policy (user not in rollout group).
final class FeatureDisabledRollout extends FeatureEvaluationResult {
  const FeatureDisabledRollout({
    required this.featureKey,
    required this.rolloutPercentage,
    this.reason,
  });

  final String featureKey;
  final int rolloutPercentage;
  final String? reason;
}

/// Feature is disabled by white-label restriction.
final class FeatureDisabledWhiteLabelRestricted extends FeatureEvaluationResult {
  const FeatureDisabledWhiteLabelRestricted({
    required this.featureKey,
    required this.whiteLabelClient,
    this.reason,
  });

  final String featureKey;
  final String whiteLabelClient;
  final String? reason;
}

/// Feature is disabled by branch restriction.
final class FeatureDisabledBranchRestricted extends FeatureEvaluationResult {
  const FeatureDisabledBranchRestricted({
    required this.featureKey,
    required this.branchId,
    this.reason,
  });

  final String featureKey;
  final String branchId;
  final String? reason;
}

/// Feature is disabled by app version incompatibility.
final class FeatureDisabledAppVersion extends FeatureEvaluationResult {
  const FeatureDisabledAppVersion({
    required this.featureKey,
    this.minVersion,
    this.maxVersion,
    this.currentVersion,
    this.reason,
  });

  final String featureKey;
  final String? minVersion;
  final String? maxVersion;
  final String? currentVersion;
  final String? reason;
}

/// Feature is disabled because it has expired.
final class FeatureDisabledExpired extends FeatureEvaluationResult {
  const FeatureDisabledExpired({
    required this.featureKey,
    required this.expiredAt,
    this.reason,
  });

  final String featureKey;
  final DateTime expiredAt;
  final String? reason;
}

/// Feature evaluation failed — config unavailable.
final class FeatureEvaluationError extends FeatureEvaluationResult {
  const FeatureEvaluationError({
    required this.featureKey,
    required this.error,
    this.fallbackEnabled = false,
  });

  final String featureKey;
  final String error;
  final bool fallbackEnabled;
}
