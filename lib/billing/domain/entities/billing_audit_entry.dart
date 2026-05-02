/// Billing audit entry — immutable record of a billing transition.
///
/// Design rationale:
/// - Append-only — entries are never modified or deleted.
/// - Carries enough context for compliance auditing.
/// - NO sensitive financial data (card numbers, amounts in clear text).
/// - Timestamps enable timeline reconstruction.
/// - Actor field tracks who/what initiated the transition.
class BillingAuditEntry {
  const BillingAuditEntry({
    required this.id,
    required this.subscriptionId,
    required this.eventType,
    required this.fromState,
    required this.toState,
    required this.actedBy,
    required this.actedAt,
    this.reason,
    this.idempotencyKey,
    this.metadata = const {},
  });

  final String id;
  final String subscriptionId;
  final String eventType;
  final String fromState;
  final String toState;
  final String actedBy;
  final DateTime actedAt;
  final String? reason;
  final String? idempotencyKey;
  final Map<String, String> metadata;
}
