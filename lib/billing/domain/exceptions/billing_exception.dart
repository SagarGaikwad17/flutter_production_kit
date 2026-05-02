/// Billing exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific billing failure mode.
/// - [BillingException] is the base for all billing errors.
/// - [SubscriptionException] covers subscription lifecycle failures.
/// - [EntitlementException] covers access control failures.
/// - [PaymentException] covers payment processing failures.
/// - [PlanException] covers plan transition failures.
/// - [InvoiceException] covers invoice lifecycle failures.
/// - NO sensitive data in exception messages.
sealed class BillingException implements Exception {
  const BillingException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'BillingException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Subscription not found.
final class SubscriptionNotFoundException extends BillingException {
  const SubscriptionNotFoundException({
    required super.message,
    this.subscriptionId,
    this.userId,
  });
  final String? subscriptionId;
  final String? userId;
}

/// Subscription state transition invalid.
final class InvalidSubscriptionTransitionException extends BillingException {
  const InvalidSubscriptionTransitionException({
    required super.message,
    required this.currentState,
    required this.requestedState,
    this.subscriptionId,
  });
  final String currentState;
  final String requestedState;
  final String? subscriptionId;
}

/// Entitlement check failed.
final class EntitlementCheckFailedException extends BillingException {
  const EntitlementCheckFailedException({
    required super.message,
    this.entitlementKey,
    this.userId,
    this.tenantId,
  });
  final String? entitlementKey;
  final String? userId;
  final String? tenantId;
}

/// Payment processing failed.
final class PaymentProcessingException extends BillingException {
  const PaymentProcessingException({
    required super.message,
    super.cause,
    this.subscriptionId,
    this.amountCents,
    this.providerError,
  });
  final String? subscriptionId;
  final int? amountCents;
  final String? providerError;
}

/// Plan not found.
final class PlanNotFoundException extends BillingException {
  const PlanNotFoundException({
    required super.message,
    this.planId,
  });
  final String? planId;
}

/// Plan transition blocked.
final class PlanTransitionBlockedException extends BillingException {
  const PlanTransitionBlockedException({
    required super.message,
    required this.currentPlanId,
    required this.targetPlanId,
    this.reason,
    this.subscriptionId,
  });
  final String currentPlanId;
  final String targetPlanId;
  final String? reason;
  final String? subscriptionId;
}

/// Invoice not found.
final class InvoiceNotFoundException extends BillingException {
  const InvoiceNotFoundException({
    required super.message,
    this.invoiceId,
  });
  final String? invoiceId;
}

/// Duplicate billing event detected.
final class DuplicateBillingEventException extends BillingException {
  const DuplicateBillingEventException({
    required super.message,
    this.idempotencyKey,
    this.eventType,
  });
  final String? idempotencyKey;
  final String? eventType;
}

/// Manual override expired.
final class ManualOverrideExpiredException extends BillingException {
  const ManualOverrideExpiredException({
    required super.message,
    this.subscriptionId,
    this.overrideExpiredAt,
  });
  final String? subscriptionId;
  final DateTime? overrideExpiredAt;
}
