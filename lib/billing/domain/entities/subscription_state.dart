/// Billing state machine — explicit subscription lifecycle states.
///
/// Design rationale:
/// - Sealed hierarchy — all states are known and exhaustive.
/// - No weak string status fields.
/// - Each state carries its own context (expiry dates, reasons, etc.).
/// - Transitions are explicit and auditable.
/// - States map directly to entitlement decisions.
///
/// State flow:
///   trial → active → grace_period → restricted_access → suspended → expired
///   active → cancelled → expired
///   active → manual_override_active → active (on override expiry)
///   any → payment_pending → active (on payment success)
///   any → payment_pending → grace_period (on payment failure)
sealed class SubscriptionState {
  const SubscriptionState({required this.since});
  final DateTime since;

  bool get isActive => this is SubscriptionActive;
  bool get isTrial => this is SubscriptionTrial;
  bool get isGracePeriod => this is SubscriptionGracePeriod;
  bool get isPaymentPending => this is SubscriptionPaymentPending;
  bool get isRestricted => this is SubscriptionRestrictedAccess;
  bool get isSuspended => this is SubscriptionSuspended;
  bool get isCancelled => this is SubscriptionCancelled;
  bool get isExpired => this is SubscriptionExpired;
  bool get isManualOverride => this is SubscriptionManualOverrideActive;
  bool get hasAccess => switch (this) {
        SubscriptionActive() ||
        SubscriptionTrial() ||
        SubscriptionGracePeriod() ||
        SubscriptionManualOverrideActive() =>
          true,
        _ => false,
      };
}

/// Subscription is active — full access granted.
final class SubscriptionActive extends SubscriptionState {
  const SubscriptionActive({
    required super.since,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.planId,
    this.autoRenew = true,
  });

  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final String planId;
  final bool autoRenew;
}

/// Subscription is in trial period — limited-time full access.
final class SubscriptionTrial extends SubscriptionState {
  const SubscriptionTrial({
    required super.since,
    required this.trialEndsAt,
    required this.planId,
  });

  final DateTime trialEndsAt;
  final String planId;
}

/// Subscription payment failed — grace period active.
///
/// User retains full access during grace period.
/// After grace expires, transitions to restricted_access.
final class SubscriptionGracePeriod extends SubscriptionState {
  const SubscriptionGracePeriod({
    required super.since,
    required this.graceEndsAt,
    required this.planId,
    required this.failedPaymentAttempts,
    this.lastPaymentError,
  });

  final DateTime graceEndsAt;
  final String planId;
  final int failedPaymentAttempts;
  final String? lastPaymentError;
}

/// Payment is in-flight — awaiting gateway confirmation.
///
/// Access is maintained during this state.
/// Resolves to active (success) or grace_period (failure).
final class SubscriptionPaymentPending extends SubscriptionState {
  const SubscriptionPaymentPending({
    required super.since,
    required this.planId,
    required this.paymentInitiatedAt,
    this.paymentProviderReference,
  });

  final String planId;
  final DateTime paymentInitiatedAt;
  final String? paymentProviderReference;
}

/// Grace expired — limited access granted.
///
/// User can view but cannot create/modify premium resources.
/// After restricted period, transitions to suspended.
final class SubscriptionRestrictedAccess extends SubscriptionState {
  const SubscriptionRestrictedAccess({
    required super.since,
    required this.planId,
    required this.restrictedSince,
    required this.allowedActions,
    this.downgradePlanId,
  });

  final String planId;
  final DateTime restrictedSince;
  final List<String> allowedActions;
  final String? downgradePlanId;
}

/// Subscription suspended — no access granted.
///
/// User cannot access any premium features.
/// Only reactivated by payment or admin intervention.
final class SubscriptionSuspended extends SubscriptionState {
  const SubscriptionSuspended({
    required super.since,
    required this.planId,
    required this.suspendedSince,
    this.reason,
  });

  final String planId;
  final DateTime suspendedSince;
  final String? reason;
}

/// Subscription cancelled by user — active until period end.
final class SubscriptionCancelled extends SubscriptionState {
  const SubscriptionCancelled({
    required super.since,
    required this.planId,
    required this.effectiveDate,
    required this.cancelledBy,
    this.reason,
  });

  final String planId;
  final DateTime effectiveDate;
  final String cancelledBy;
  final String? reason;
}

/// Subscription expired — natural end of lifecycle.
final class SubscriptionExpired extends SubscriptionState {
  const SubscriptionExpired({
    required super.since,
    required this.planId,
    required this.expiredAt,
  });

  final String planId;
  final DateTime expiredAt;
}

/// Admin override active — temporary access granted by support.
final class SubscriptionManualOverrideActive extends SubscriptionState {
  const SubscriptionManualOverrideActive({
    required super.since,
    required this.planId,
    required this.overrideGrantedBy,
    required this.overrideExpiresAt,
    required this.overrideReason,
    this.overrideEntitlements = const [],
  });

  final String planId;
  final String overrideGrantedBy;
  final DateTime overrideExpiresAt;
  final String overrideReason;
  final List<String> overrideEntitlements;
}
