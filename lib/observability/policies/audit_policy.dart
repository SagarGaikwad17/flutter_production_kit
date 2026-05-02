/// Audit policy — defines audit recording rules and compliance requirements.
///
/// Design rationale:
/// - Determines which actions MUST be audited.
/// - Defines audit retention requirements.
/// - Configurable per-module audit levels.
/// - Ensures compliance with regulatory requirements.
///
/// Audit levels:
///   - None: no audit recording.
///   - Minimal: only success/failure recorded.
///   - Full: all details recorded including metadata.
///   - Compliance: full audit with additional compliance fields.
class AuditPolicy {
  const AuditPolicy({
    this.defaultAuditLevel = AuditLevel.full,
    this.moduleLevels = const {},
    this.requireCorrelationId = true,
    this.maskSensitiveData = true,
    this.maxMetadataFields = 20,
    this.criticalActions = const [
      'create_subscription',
      'cancel_subscription',
      'grant_override',
      'revoke_override',
      'delete_data',
      'export_data',
      'change_role',
      'change_permissions',
    ],
  });

  final AuditLevel defaultAuditLevel;
  final Map<String, AuditLevel> moduleLevels;
  final bool requireCorrelationId;
  final bool maskSensitiveData;
  final int maxMetadataFields;
  final List<String> criticalActions;

  /// Get the audit level for a module.
  AuditLevel getLevelForModule(String module) {
    return moduleLevels[module] ?? defaultAuditLevel;
  }

  /// Check if an action requires mandatory auditing.
  bool requiresMandatoryAudit(String action) {
    return criticalActions.any((critical) => action.contains(critical));
  }
}

enum AuditLevel {
  none,
  minimal,
  full,
  compliance,
}
