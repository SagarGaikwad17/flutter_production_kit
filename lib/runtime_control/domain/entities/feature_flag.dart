/// Immutable feature flag — the fundamental unit of runtime control.
///
/// Design rationale:
/// - Every feature is controlled by a flag with rich evaluation rules.
/// - [key] is the stable identifier — never change after deployment.
/// - [enabled] is the base state — further refined by targeting and rollout.
/// - [targetingRules] are evaluated in order — first match wins.
/// - [rolloutPercentage] controls gradual rollout (0–100).
/// - [rolloutSalt] ensures deterministic assignment across evaluations.
/// - [killSwitchKey] links to emergency kill switch for instant disable.
/// - [requiredEntitlements] enforces subscription-based access.
/// - [allowedTenants] / [blockedTenants] enforce tenant isolation.
/// - [allowedBranches] / [blockedBranches] enforce branch-level control.
/// - [allowedWhiteLabels] / [blockedWhiteLabels] enforce client isolation.
/// - [metadata] carries safe diagnostic data — NEVER sensitive info.
/// - [expiresAt] supports time-limited feature availability (beta, promo).
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    this.enabled = false,
    this.targetingRules = const [],
    this.rolloutPercentage = 100,
    this.rolloutSalt = '',
    this.killSwitchKey,
    this.requiredEntitlements = const [],
    this.allowedTenants,
    this.blockedTenants,
    this.allowedBranches,
    this.blockedBranches,
    this.allowedWhiteLabels,
    this.blockedWhiteLabels,
    this.allowedRegions,
    this.blockedRegions,
    this.minAppVersion,
    this.maxAppVersion,
    this.expiresAt,
    this.evaluationOrder = EvaluationOrder.targetingFirst,
    this.metadata = const {},
  });

  final String key;
  final bool enabled;
  final List<TargetingRule> targetingRules;
  final int rolloutPercentage;
  final String rolloutSalt;
  final String? killSwitchKey;
  final List<String> requiredEntitlements;
  final List<String>? allowedTenants;
  final List<String>? blockedTenants;
  final List<String>? allowedBranches;
  final List<String>? blockedBranches;
  final List<String>? allowedWhiteLabels;
  final List<String>? blockedWhiteLabels;
  final List<String>? allowedRegions;
  final List<String>? blockedRegions;
  final String? minAppVersion;
  final String? maxAppVersion;
  final DateTime? expiresAt;
  final EvaluationOrder evaluationOrder;
  final Map<String, String> metadata;

  bool get isExpired {
    final expires = expiresAt;
    if (expires == null) return false;
    return DateTime.now().isAfter(expires);
  }

  bool get hasTargeting => targetingRules.isNotEmpty;

  @override
  String toString() => 'FeatureFlag($key, enabled: $enabled, rollout: $rolloutPercentage%)';
}

/// Targeting rule — defines who gets access to a feature.
///
/// Rules are evaluated in order. First match wins.
/// Each rule can target by user ID, role, segment, or custom criteria.
class TargetingRule {
  const TargetingRule({
    required this.id,
    required this.condition,
    this.priority = 0,
    this.description,
  });

  final String id;
  final TargetingCondition condition;
  final int priority;
  final String? description;

  @override
  String toString() => 'TargetingRule($id, priority: $priority)';
}

/// Targeting condition — the criteria for a targeting rule.
sealed class TargetingCondition {
  const TargetingCondition();
}

final class UserIdsCondition extends TargetingCondition {
  const UserIdsCondition({required this.userIds});
  final Set<String> userIds;
}

final class RolesCondition extends TargetingCondition {
  const RolesCondition({required this.roles});
  final Set<String> roles;
}

final class SegmentsCondition extends TargetingCondition {
  const SegmentsCondition({required this.segments});
  final Set<String> segments;
}

final class TenantIdsCondition extends TargetingCondition {
  const TenantIdsCondition({required this.tenantIds});
  final Set<String> tenantIds;
}

final class BranchIdsCondition extends TargetingCondition {
  const BranchIdsCondition({required this.branchIds});
  final Set<String> branchIds;
}

final class PercentageCondition extends TargetingCondition {
  const PercentageCondition({required this.percentage, this.salt = ''});
  final int percentage;
  final String salt;
}

final class CustomCondition extends TargetingCondition {
  const CustomCondition({required this.evaluatorKey, this.parameters = const {}});
  final String evaluatorKey;
  final Map<String, String> parameters;
}

enum EvaluationOrder {
  targetingFirst,
  rolloutFirst,
  entitlementsFirst,
}
