/// Billing access result — explicit outcome of an entitlement check.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No bool-only checks — each result carries context.
/// - UI layer can pattern-match to show correct messaging.
/// - Audit layer can log the exact access decision.
/// - Engine layer can take corrective action based on result type.
///
/// Outcomes:
/// - AccessGranted: full access, subscription active.
/// - AccessGrantedTrial: full access, trial period.
/// - AccessGrantedGracePeriod: full access, payment failed but within grace.
/// - AccessGrantedManualOverride: full access, admin override active.
/// - AccessRestricted: limited access, grace expired.
/// - AccessBlockedExpired: no access, subscription expired.
/// - AccessBlockedSuspended: no access, suspended (non-payment).
/// - AccessBlockedDowngrade: blocked by downgrade policy.
/// - AccessBlockedMissingEntitlement: blocked by missing plan entitlement.
/// - AccessBlockedTenantMismatch: blocked by tenant restriction.
/// - BillingVerificationPending: awaiting payment confirmation.
sealed class BillingAccessResult {
  const BillingAccessResult({required this.entitlementKey});
  final String entitlementKey;

  bool get isGranted => switch (this) {
        BillingAccessGranted() ||
        BillingAccessGrantedTrial() ||
        BillingAccessGrantedGracePeriod() ||
        BillingAccessGrantedManualOverride() =>
          true,
        _ => false,
      };

  bool get isRestricted => this is BillingAccessRestricted;
  bool get isBlocked => !isGranted && !isRestricted;
}

/// Full access granted — subscription active.
final class BillingAccessGranted extends BillingAccessResult {
  const BillingAccessGranted({
    required super.entitlementKey,
    required this.planId,
    required this.planTier,
    this.reason,
  });

  final String planId;
  final String planTier;
  final String? reason;
}

/// Full access granted — trial period.
final class BillingAccessGrantedTrial extends BillingAccessResult {
  const BillingAccessGrantedTrial({
    required super.entitlementKey,
    required this.planId,
    required this.trialEndsAt,
  });

  final String planId;
  final DateTime trialEndsAt;
}

/// Full access granted — grace period active.
final class BillingAccessGrantedGracePeriod extends BillingAccessResult {
  const BillingAccessGrantedGracePeriod({
    required super.entitlementKey,
    required this.planId,
    required this.graceEndsAt,
    required this.failedPaymentAttempts,
  });

  final String planId;
  final DateTime graceEndsAt;
  final int failedPaymentAttempts;
}

/// Full access granted — admin override active.
final class BillingAccessGrantedManualOverride extends BillingAccessResult {
  const BillingAccessGrantedManualOverride({
    required super.entitlementKey,
    required this.planId,
    required this.overrideGrantedBy,
    required this.overrideExpiresAt,
    required this.overrideReason,
  });

  final String planId;
  final String overrideGrantedBy;
  final DateTime overrideExpiresAt;
  final String overrideReason;
}

/// Restricted access — limited features available.
final class BillingAccessRestricted extends BillingAccessResult {
  const BillingAccessRestricted({
    required super.entitlementKey,
    required this.planId,
    required this.allowedActions,
    required this.reason,
    this.downgradePlanId,
  });

  final String planId;
  final List<String> allowedActions;
  final String reason;
  final String? downgradePlanId;
}

/// Access blocked — subscription expired.
final class BillingAccessBlockedExpired extends BillingAccessResult {
  const BillingAccessBlockedExpired({
    required super.entitlementKey,
    required this.planId,
    required this.expiredAt,
    this.reason,
  });

  final String planId;
  final DateTime expiredAt;
  final String? reason;
}

/// Access blocked — subscription suspended.
final class BillingAccessBlockedSuspended extends BillingAccessResult {
  const BillingAccessBlockedSuspended({
    required super.entitlementKey,
    required this.planId,
    required this.suspendedSince,
    this.reason,
  });

  final String planId;
  final DateTime suspendedSince;
  final String? reason;
}

/// Access blocked — downgrade policy prevents access.
final class BillingAccessBlockedDowngrade extends BillingAccessResult {
  const BillingAccessBlockedDowngrade({
    required super.entitlementKey,
    required this.currentPlanId,
    required this.targetPlanId,
    required this.reason,
  });

  final String currentPlanId;
  final String targetPlanId;
  final String reason;
}

/// Access blocked — missing plan entitlement.
final class BillingAccessBlockedMissingEntitlement extends BillingAccessResult {
  const BillingAccessBlockedMissingEntitlement({
    required super.entitlementKey,
    required this.planId,
    required this.requiredEntitlement,
    this.reason,
  });

  final String planId;
  final String requiredEntitlement;
  final String? reason;
}

/// Access blocked — tenant mismatch.
final class BillingAccessBlockedTenantMismatch extends BillingAccessResult {
  const BillingAccessBlockedTenantMismatch({
    required super.entitlementKey,
    required this.planId,
    required this.userTenant,
    required this.allowedTenants,
  });

  final String planId;
  final String userTenant;
  final List<String> allowedTenants;
}

/// Billing verification pending — awaiting payment confirmation.
final class BillingVerificationPending extends BillingAccessResult {
  const BillingVerificationPending({
    required super.entitlementKey,
    required this.planId,
    required this.paymentReference,
    this.reason,
  });

  final String planId;
  final String paymentReference;
  final String? reason;
}
