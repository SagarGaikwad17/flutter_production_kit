import 'package:flutter_production_kit/billing/domain/entities/billing_audit_entry.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Billing audit manager — manages immutable audit trail for all billing transitions.
///
/// Design rationale:
/// - Append-only audit log — entries are never modified or deleted.
/// - All billing transitions MUST be audited.
/// - NO sensitive financial data in audit entries.
/// - Supports compliance reporting and dispute resolution.
/// - Audit entries are indexed by subscription, user, and event type.
class BillingAuditManager {
  BillingAuditManager({
    required BillingAuditRepository auditRepository,
  }) : _auditRepository = auditRepository;

  static const String _tag = 'BillingAuditManager';

  final BillingAuditRepository _auditRepository;

  /// Record a billing transition.
  Future<void> recordTransition({
    required String subscriptionId,
    required String eventType,
    required String fromState,
    required String toState,
    required String actedBy,
    String? reason,
    String? idempotencyKey,
    Map<String, String>? metadata,
  }) async {
    final entry = BillingAuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      eventType: eventType,
      fromState: fromState,
      toState: toState,
      actedBy: actedBy,
      actedAt: DateTime.now(),
      reason: reason,
      idempotencyKey: idempotencyKey,
      metadata: metadata ?? {},
    );

    await _auditRepository.saveAuditEntry(entry);
    AppLogger.debug(_tag, 'Audit: $subscriptionId ($fromState → $toState)');
  }

  /// Get audit trail for a subscription.
  Future<List<BillingAuditEntry>> getSubscriptionAuditTrail(String subscriptionId) {
    return _auditRepository.getEntriesForSubscription(subscriptionId);
  }

  /// Get audit trail for a user.
  Future<List<BillingAuditEntry>> getUserAuditTrail(String userId) {
    return _auditRepository.getEntriesForUser(userId);
  }

  /// Get all manual override audit entries.
  Future<List<BillingAuditEntry>> getManualOverrideAudits() {
    return _auditRepository.getEntriesByEventType('manual_override');
  }

  /// Get all downgrade audit entries.
  Future<List<BillingAuditEntry>> getDowngradeAudits() {
    return _auditRepository.getEntriesByEventType('downgrade');
  }

  /// Get all duplicate billing event audit entries.
  Future<List<BillingAuditEntry>> getDuplicateEventAudits() {
    return _auditRepository.getEntriesByEventType('duplicate_event');
  }
}
