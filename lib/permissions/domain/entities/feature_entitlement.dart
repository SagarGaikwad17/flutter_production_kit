/// Feature entitlement — subscription-based feature access.
///
/// Design rationale:
/// - Entitlements are separate from role permissions.
/// - A user may have the "billing_admin" role but no entitlement to the
///   "advanced_analytics" feature if their subscription doesn't include it.
/// - [featureId] is the stable identifier for the feature.
/// - [tier] defines the subscription tier required (free, basic, premium, enterprise).
/// - [expiresAt] supports time-limited entitlements (trial, promo).
/// - [branchIds] limits the entitlement to specific branches.
/// - Entitlement checks happen AFTER role permission checks.
class FeatureEntitlement {
  const FeatureEntitlement({
    required this.featureId,
    required this.tier,
    this.enabled = true,
    this.expiresAt,
    this.branchIds,
    this.metadata = const {},
  });

  final String featureId;
  final SubscriptionTier tier;
  final bool enabled;
  final DateTime? expiresAt;
  final List<String>? branchIds;
  final Map<String, String> metadata;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool get isActive => enabled && !isExpired;

  /// Check if this entitlement applies to the given branch.
  bool appliesToBranch(String? branchId) {
    if (branchIds == null || branchIds!.isEmpty) return true;
    if (branchId == null) return false;
    return branchIds!.contains(branchId);
  }
}

/// Subscription tiers — ordered by access level.
enum SubscriptionTier {
  free(level: 0),
  basic(level: 10),
  premium(level: 50),
  enterprise(level: 100);

  const SubscriptionTier({required this.level});

  final int level;

  bool canAccess(SubscriptionTier required) => level >= required.level;
}
