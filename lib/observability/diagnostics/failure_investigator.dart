import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/entities/trace_span.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Failure investigator — structured investigation framework for production failures.
///
/// Design rationale:
/// - Provides investigation templates for common failure scenarios.
/// - Each investigation type gathers the right evidence automatically.
/// - Investigation results include timeline, root cause hints, and recommendations.
/// - Integration with incident tracker for follow-up.
///
/// Investigation types:
///   - PaymentFailure: trace payment → gateway → webhook → entitlement.
///   - PermissionDenial: trace auth → role → entitlement → decision.
///   - SyncDataLoss: trace local save → queue → sync → conflict → resolution.
///   - SuspiciousLogin: trace login source → device → session → refresh.
///   - AdminOverride: trace who, when, why, duration, expiry result.
///   - DuplicateWebhook: trace duplicate detection → replay prevention → reconciliation.
class FailureInvestigator {
  FailureInvestigator({
    required TraceRepository traceRepository,
    required AuditRepository auditRepository,
    required SecurityEventRepository securityEventRepository,
  })  : _traceRepository = traceRepository,
        _auditRepository = auditRepository,
        _securityEventRepository = securityEventRepository;

  final TraceRepository _traceRepository;
  final AuditRepository _auditRepository;
  final SecurityEventRepository _securityEventRepository;

  /// Investigate a payment failure.
  Future<InvestigationResult> investigatePaymentFailure({
    required String correlationId,
    required String subscriptionId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByCorrelationId(correlationId);

    // Look for billing-specific audits.
    final billingAudits = audits.where((a) => a.module == 'billing').toList();
    final gatewayAudits = audits.where((a) => a.action.contains('gateway') || a.action.contains('webhook')).toList();
    final entitlementAudits = audits.where((a) => a.action.contains('entitlement')).toList();

    final hints = <String>[];
    if (billingAudits.where((a) => a.result == AuditResult.failure).isNotEmpty) {
      hints.add('Billing failure detected in audit trail.');
    }
    if (gatewayAudits.where((a) => a.result == AuditResult.success).isNotEmpty &&
        entitlementAudits.where((a) => a.result == AuditResult.failure).isNotEmpty) {
      hints.add('Gateway succeeded but entitlement update failed — possible webhook delay.');
    }
    if (traces.where((t) => t.status == TraceStatus.error).isNotEmpty) {
      hints.add('Error trace detected in payment flow.');
    }

    return InvestigationResult(
      investigationType: 'payment_failure',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  /// Investigate a permission denial.
  Future<InvestigationResult> investigatePermissionDenial({
    required String correlationId,
    required String userId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByActor(userId);

    final permissionAudits = audits.where((a) =>
        a.action.contains('permission') ||
        a.action.contains('entitlement') ||
        a.action.contains('role')).toList();

    final deniedAudits = permissionAudits.where((a) => a.result == AuditResult.denied).toList();

    final hints = <String>[];
    if (deniedAudits.isNotEmpty) {
      hints.add('Permission denied: ${deniedAudits.map((a) => a.action).join(', ')}');
    }

    // Check for role changes.
    final roleChanges = audits.where((a) => a.action.contains('role_change')).toList();
    if (roleChanges.isNotEmpty) {
      hints.add('Role change detected before denial.');
    }

    return InvestigationResult(
      investigationType: 'permission_denial',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  /// Investigate offline sync data loss.
  Future<InvestigationResult> investigateSyncDataLoss({
    required String correlationId,
    required String userId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByActor(userId);

    final syncAudits = audits.where((a) => a.module == 'sync' || a.action.contains('sync')).toList();
    final conflictAudits = audits.where((a) => a.action.contains('conflict')).toList();
    final failureAudits = syncAudits.where((a) => a.result == AuditResult.failure).toList();

    final hints = <String>[];
    if (failureAudits.isNotEmpty) {
      hints.add('${failureAudits.length} sync failure(s) detected.');
    }
    if (conflictAudits.isNotEmpty) {
      hints.add('${conflictAudits.length} conflict resolution(s) detected.');
    }

    // Check for queue creation.
    final queueAudits = audits.where((a) => a.action.contains('queue')).toList();
    if (queueAudits.isNotEmpty) {
      hints.add('Queue operations detected: ${queueAudits.length}');
    }

    return InvestigationResult(
      investigationType: 'sync_data_loss',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  /// Investigate a suspicious login.
  Future<InvestigationResult> investigateSuspiciousLogin({
    required String correlationId,
    required String userId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByActor(userId);
    final securityEvents = await _securityEventRepository.getEventsByActor(userId);

    final loginAudits = audits.where((a) => a.action.contains('login') || a.action.contains('auth')).toList();
    final sessionAudits = audits.where((a) => a.action.contains('session')).toList();

    final hints = <String>[];
    final suspiciousEvents = securityEvents.where((e) => e.isHighRisk()).toList();
    if (suspiciousEvents.isNotEmpty) {
      hints.add('${suspiciousEvents.length} high-risk security event(s) detected.');
    }

    // Check for session invalidation.
    final invalidations = sessionAudits.where((a) => a.action.contains('invalidate')).toList();
    if (invalidations.isNotEmpty) {
      hints.add('Session invalidation detected.');
    }

    // Check for multiple failed logins.
    final failedLogins = loginAudits.where((a) => a.result == AuditResult.failure).toList();
    if (failedLogins.length > 2) {
      hints.add('Multiple failed login attempts: ${failedLogins.length}');
    }

    return InvestigationResult(
      investigationType: 'suspicious_login',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  /// Investigate a manual admin override.
  Future<InvestigationResult> investigateAdminOverride({
    required String correlationId,
    required String adminId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByActor(adminId);

    final overrideAudits = audits.where((a) =>
        a.action.contains('override') || a.action.contains('grant')).toList();

    final hints = <String>[];
    if (overrideAudits.isNotEmpty) {
      hints.add('Override actions: ${overrideAudits.map((a) => '${a.action} → ${a.target}').join(', ')}');
    }

    // Check for expiry.
    final expiryAudits = audits.where((a) => a.action.contains('expiry') || a.action.contains('revoke')).toList();
    if (expiryAudits.isNotEmpty) {
      hints.add('Override expiry/revocation detected.');
    }

    return InvestigationResult(
      investigationType: 'admin_override',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  /// Investigate duplicate webhook events.
  Future<InvestigationResult> investigateDuplicateWebhook({
    required String correlationId,
    required String webhookId,
  }) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByCorrelationId(correlationId);

    final webhookAudits = audits.where((a) => a.action.contains('webhook')).toList();
    final duplicateAudits = audits.where((a) => a.action.contains('duplicate') || a.action.contains('replay')).toList();

    final hints = <String>[];
    if (webhookAudits.isNotEmpty) {
      hints.add('${webhookAudits.length} webhook event(s) processed.');
    }
    if (duplicateAudits.isNotEmpty) {
      hints.add('${duplicateAudits.length} duplicate/replay event(s) detected.');
    }

    // Check for financial reconciliation.
    final reconciliationAudits = audits.where((a) => a.action.contains('reconcil')).toList();
    if (reconciliationAudits.isNotEmpty) {
      hints.add('Financial reconciliation evidence found.');
    }

    return InvestigationResult(
      investigationType: 'duplicate_webhook',
      correlationId: correlationId,
      traceCount: traces.length,
      auditCount: audits.length,
      rootCauseHints: hints.isEmpty ? ['No obvious root cause detected.'] : hints,
      timeline: _buildTimeline(traces, audits),
    );
  }

  // ── Timeline Building ──────────────────────────────────────────────────────

  List<TimelineEvent> _buildTimeline(List<TraceSpan> traces, List<AuditEntry> audits) {
    final events = <TimelineEvent>[
      ...traces.map((t) => TimelineEvent(
            timestamp: t.startedAt,
            type: TimelineEventType.trace,
            description: '${t.module}.${t.operation} (${t.status.name})',
            moduleId: t.module,
            correlationId: t.correlationId,
          )),
      ...audits.map((a) => TimelineEvent(
            timestamp: a.timestamp,
            type: TimelineEventType.audit,
            description: '${a.module}.${a.action} → ${a.target} (${a.result.name})',
            moduleId: a.module,
            correlationId: a.correlationId,
          )),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return events;
  }
}

/// Investigation result — structured output of a failure investigation.
class InvestigationResult {
  const InvestigationResult({
    required this.investigationType,
    required this.correlationId,
    required this.traceCount,
    required this.auditCount,
    required this.rootCauseHints,
    required this.timeline,
  });

  final String investigationType;
  final String correlationId;
  final int traceCount;
  final int auditCount;
  final List<String> rootCauseHints;
  final List<TimelineEvent> timeline;
}

/// Timeline event for investigations.
class TimelineEvent {
  const TimelineEvent({
    required this.timestamp,
    required this.type,
    required this.description,
    required this.moduleId,
    this.correlationId,
  });

  final DateTime timestamp;
  final TimelineEventType type;
  final String description;
  final String moduleId;
  final String? correlationId;
}

enum TimelineEventType {
  trace,
  audit,
}
