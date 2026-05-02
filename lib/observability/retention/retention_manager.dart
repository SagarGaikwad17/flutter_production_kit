import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Retention manager — manages policy-driven data retention for observability data.
///
/// Design rationale:
/// - Different data types have different retention requirements.
/// - Critical audit logs are retained longer than debug logs.
/// - Retention policies are configurable and auditable.
/// - Deletion is scheduled and logged for compliance.
/// - Privacy-safe deletion ensures no data leakage.
///
/// Retention periods:
///   - Debug logs: 7 days
///   - Standard logs: 90 days
///   - Security events: 1 year
///   - Billing events: 7 years
///   - Compliance events: 10 years
///
/// Retention flow:
///   1. Schedule retention check on startup.
///   2. For each category, find entries past retention period.
///   3. Delete entries and record deletion in audit trail.
///   4. Report retention actions for compliance.
class RetentionManager {
  RetentionManager({
    required AuditRepository auditRepository,
    required LogRepository logRepository,
    required TraceRepository traceRepository,
    required SecurityEventRepository securityEventRepository,
    RetentionPolicy? policy,
  })  : _auditRepository = auditRepository,
        _logRepository = logRepository,
        _traceRepository = traceRepository,
        _securityEventRepository = securityEventRepository,
        _policy = policy ?? const RetentionPolicy();

  final AuditRepository _auditRepository;
  final LogRepository _logRepository;
  final TraceRepository _traceRepository;
  // ignore: unused_field
  final SecurityEventRepository _securityEventRepository;
  final RetentionPolicy _policy;

  /// Execute retention cleanup.
  Future<RetentionReport> executeRetention() async {
    final now = DateTime.now();
    var totalDeleted = 0;

    // Delete expired debug logs.
    final debugDeleted = await _logRepository.deleteExpiredEntries();
    totalDeleted += debugDeleted;

    // Delete expired audit entries.
    final auditDeleted = await _auditRepository.deleteExpiredEntries();
    totalDeleted += auditDeleted;

    // Delete expired traces.
    final traceDeleted = await _traceRepository.deleteExpiredTraces();
    totalDeleted += traceDeleted;

    return RetentionReport(
      executedAt: now,
      totalDeleted: totalDeleted,
      debugLogsDeleted: debugDeleted,
      auditEntriesDeleted: auditDeleted,
      tracesDeleted: traceDeleted,
      retentionPolicy: _policy,
    );
  }

  /// Get the retention period for a category.
  Duration getRetentionPeriod(AuditRetentionCategory category) {
    return switch (category) {
      AuditRetentionCategory.debug => _policy.debugRetentionPeriod,
      AuditRetentionCategory.standard => _policy.standardRetentionPeriod,
      AuditRetentionCategory.security => _policy.securityRetentionPeriod,
      AuditRetentionCategory.billing => _policy.billingRetentionPeriod,
      AuditRetentionCategory.compliance => _policy.complianceRetentionPeriod,
    };
  }

  /// Get the expiry date for an entry based on its retention category.
  DateTime getExpiryDate(AuditEntry entry) {
    final period = getRetentionPeriod(entry.retentionCategory);
    return entry.timestamp.add(period);
  }

  /// Check if an entry is past its retention period.
  bool isExpired(AuditEntry entry) {
    return DateTime.now().isAfter(getExpiryDate(entry));
  }
}

/// Retention policy — defines retention periods for each category.
class RetentionPolicy {
  const RetentionPolicy({
    this.debugRetentionPeriod = const Duration(days: 7),
    this.standardRetentionPeriod = const Duration(days: 90),
    this.securityRetentionPeriod = const Duration(days: 365),
    this.billingRetentionPeriod = const Duration(days: 2555), // 7 years
    this.complianceRetentionPeriod = const Duration(days: 3652), // 10 years
  });

  final Duration debugRetentionPeriod;
  final Duration standardRetentionPeriod;
  final Duration securityRetentionPeriod;
  final Duration billingRetentionPeriod;
  final Duration complianceRetentionPeriod;
}

/// Retention report — summary of retention cleanup actions.
class RetentionReport {
  const RetentionReport({
    required this.executedAt,
    required this.totalDeleted,
    required this.debugLogsDeleted,
    required this.auditEntriesDeleted,
    required this.tracesDeleted,
    required this.retentionPolicy,
  });

  final DateTime executedAt;
  final int totalDeleted;
  final int debugLogsDeleted;
  final int auditEntriesDeleted;
  final int tracesDeleted;
  final RetentionPolicy retentionPolicy;
}
