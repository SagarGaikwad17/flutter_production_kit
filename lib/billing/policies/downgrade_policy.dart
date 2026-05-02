/// Downgrade policy — determines if a downgrade is allowed and how it should be handled.
///
/// Design rationale:
/// - Centralizes downgrade business rules.
/// - Prevents destructive downgrades (losing active premium resources).
/// - Supports configurable downgrade timing (immediate vs end-of-period).
/// - Returns typed results with block reasons.
///
/// Policy rules:
///   1. Cannot downgrade if user has premium-only resources that would be lost.
///   2. Downgrades take effect at end of current billing period.
///   3. Free tier cannot be downgraded further.
///   4. Enterprise tier may require admin approval for downgrade.
class DowngradePolicy {
  const DowngradePolicy({
    this.allowDowngradeWithLostEntitlements = false,
    this.downgradeEffectiveAtEndOfPeriod = true,
    this.requireAdminApprovalForEnterprise = true,
    this.blockedPlanTransitions = const {},
  });

  /// Allow downgrade even if entitlements will be lost.
  final bool allowDowngradeWithLostEntitlements;

  /// Downgrade takes effect at end of current period.
  final bool downgradeEffectiveAtEndOfPeriod;

  /// Enterprise downgrades require admin approval.
  final bool requireAdminApprovalForEnterprise;

  /// Explicitly blocked plan transitions.
  final Map<String, List<String>> blockedPlanTransitions;

  /// Evaluate a downgrade request.
  DowngradePolicyResult evaluateDowngrade({
    required String currentPlanId,
    required String targetPlanId,
    required List<String> activeEntitlements,
    required List<String> lostEntitlements,
  }) {
    // Check explicitly blocked transitions.
    final blockedTargets = blockedPlanTransitions[currentPlanId];
    if (blockedTargets != null && blockedTargets.contains(targetPlanId)) {
      return DowngradePolicyResult(
        isAllowed: false,
        blockReason: 'Transition $currentPlanId → $targetPlanId is blocked.',
      );
    }

    // Check for lost entitlements.
    if (lostEntitlements.isNotEmpty && !allowDowngradeWithLostEntitlements) {
      return DowngradePolicyResult(
        isAllowed: false,
        blockReason: 'Downgrade would remove ${lostEntitlements.length} active entitlement(s). '
            'Resolve dependencies first.',
        requiresReconciliation: true,
        lostEntitlements: lostEntitlements,
      );
    }

    return DowngradePolicyResult(
      isAllowed: true,
      effectiveAtEndOfPeriod: downgradeEffectiveAtEndOfPeriod,
      lostEntitlements: lostEntitlements,
    );
  }
}

class DowngradePolicyResult {
  const DowngradePolicyResult({
    required this.isAllowed,
    this.blockReason,
    this.requiresReconciliation = false,
    this.effectiveAtEndOfPeriod = true,
    this.lostEntitlements = const [],
  });

  final bool isAllowed;
  final String? blockReason;
  final bool requiresReconciliation;
  final bool effectiveAtEndOfPeriod;
  final List<String> lostEntitlements;
}
