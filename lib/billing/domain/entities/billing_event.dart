/// Billing event — idempotent webhook or system event.
///
/// Design rationale:
/// - [id] is the unique event identifier (often from payment provider).
/// - [idempotencyKey] deduplicates replays.
/// - [type] determines the event handler.
/// - [payload] carries safe event data — NO sensitive financial details.
/// - [receivedAt] enables replay detection and ordering.
/// - [processedAt] tracks idempotent completion.
///
/// Events are processed exactly-once via idempotency key.
/// Duplicate events are logged and silently ignored.
class BillingEvent {
  const BillingEvent({
    required this.id,
    required this.idempotencyKey,
    required this.type,
    required this.receivedAt,
    this.subscriptionId,
    this.userId,
    this.tenantId,
    this.payload = const {},
    this.processedAt,
    this.metadata = const {},
  });

  final String id;
  final String idempotencyKey;
  final BillingEventType type;
  final String? subscriptionId;
  final String? userId;
  final String? tenantId;
  final Map<String, String> payload;
  final DateTime receivedAt;
  final DateTime? processedAt;
  final Map<String, String> metadata;

  bool get isProcessed => processedAt != null;
}

enum BillingEventType {
  /// Subscription created.
  subscriptionCreated,

  /// Subscription activated (payment confirmed).
  subscriptionActivated,

  /// Payment succeeded (renewal or initial).
  paymentSucceeded,

  /// Payment failed (renewal declined).
  paymentFailed,

  /// Payment retry initiated.
  paymentRetryInitiated,

  /// Subscription cancelled by user.
  subscriptionCancelled,

  /// Subscription expired (natural end).
  subscriptionExpired,

  /// Subscription upgraded.
  subscriptionUpgraded,

  /// Subscription downgraded.
  subscriptionDowngraded,

  /// Trial started.
  trialStarted,

  /// Trial ended (converted or expired).
  trialEnded,

  /// Grace period entered.
  gracePeriodEntered,

  /// Grace period exited (payment succeeded).
  gracePeriodExited,

  /// Restricted access entered.
  restrictedAccessEntered,

  /// Access suspended.
  accessSuspended,

  /// Manual override granted.
  manualOverrideGranted,

  /// Manual override revoked.
  manualOverrideRevoked,

  /// Invoice created.
  invoiceCreated,

  /// Invoice paid.
  invoicePaid,

  /// Invoice payment failed.
  invoicePaymentFailed,

  /// Refund issued.
  refundIssued,

  /// Charge disputed.
  chargeDisputed,
}
