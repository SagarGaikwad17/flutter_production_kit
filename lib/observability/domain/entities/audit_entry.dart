/// Audit entry — immutable record of a business-critical action.
///
/// Design rationale:
/// - Append-only — entries are NEVER modified or deleted.
/// - Carries enough context for compliance investigations.
/// - NO sensitive data (tokens, PII, card numbers).
/// - [actorId] identifies who performed the action (user-safe identifier).
/// - [action] describes what was done.
/// - [target] identifies what was affected.
/// - [result] records the outcome.
/// - [correlationId] links to related traces for full investigation.
/// - Timestamps enable timeline reconstruction.
/// - [lockVersion] prevents tampering detection.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.actorId,
    required this.action,
    required this.target,
    required this.result,
    required this.module,
    this.correlationId,
    this.reason,
    this.metadata = const {},
    this.lockVersion = 1,
    this.retentionCategory = AuditRetentionCategory.standard,
  });

  final String id;
  final DateTime timestamp;
  final String actorId;
  final String action;
  final String target;
  final AuditResult result;
  final String module;
  final String? correlationId;
  final String? reason;
  final Map<String, String> metadata;
  final int lockVersion;
  final AuditRetentionCategory retentionCategory;

  bool get isLocked => lockVersion > 0;

  AuditEntry copyWithLocked() {
    return AuditEntry(
      id: id,
      timestamp: timestamp,
      actorId: actorId,
      action: action,
      target: target,
      result: result,
      module: module,
      correlationId: correlationId,
      reason: reason,
      metadata: metadata,
      lockVersion: lockVersion + 1,
      retentionCategory: retentionCategory,
    );
  }
}

enum AuditResult {
  success,
  failure,
  denied,
  overridden,
  skipped,
}

enum AuditRetentionCategory {
  /// Debug logs — retained for 7 days.
  debug,

  /// Standard operational logs — retained for 90 days.
  standard,

  /// Security events — retained for 1 year.
  security,

  /// Billing/financial events — retained for 7 years.
  billing,

  /// Compliance-critical events — retained for 10 years.
  compliance,
}
