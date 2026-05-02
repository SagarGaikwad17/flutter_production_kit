/// Deployment audit engine — records immutable deployment audit trail.
///
/// Design rationale:
/// - Every deployment event is recorded.
/// - Audit records are immutable — cannot be modified after creation.
/// - Audit records are timestamped and attributed.
/// - Secret-safe — no sensitive data in audit records.
/// - Supports compliance requirements for regulated industries.
///
/// Audit event types:
/// - Release created.
/// - Release validated.
/// - Release signed.
/// - Release approved.
/// - Release deployed.
/// - Rollout started.
/// - Rollout paused.
/// - Rollout resumed.
/// - Rollout completed.
/// - Rollback initiated.
/// - Rollback completed.
/// - Flavor validation passed.
/// - Flavor validation failed.
/// - Signing completed.
/// - Signing failed.
/// - Approval submitted.
/// - Approval rejected.
/// - Environment validation passed.
/// - Environment validation failed.
class DeploymentAuditEngine {
  const DeploymentAuditEngine({
    required void Function(DeploymentAuditEvent event) onAuditEvent,
  }) : _onAuditEvent = onAuditEvent;

  final void Function(DeploymentAuditEvent event) _onAuditEvent;

  /// Record a release creation event.
  void recordReleaseCreated({
    required String releaseId,
    required String version,
    required String flavor,
    required String environment,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.releaseCreated,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'version': version,
        'flavor': flavor,
        'environment': environment,
      },
    ));
  }

  /// Record a release validation event.
  void recordReleaseValidated({
    required String releaseId,
    required String flavor,
    required String checksum,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.releaseValidated,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'flavor': flavor,
        'checksum': checksum,
      },
    ));
  }

  /// Record a release signing event.
  void recordReleaseSigned({
    required String releaseId,
    required String platform,
    required String keyAlias,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.releaseSigned,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'platform': platform,
        'key_alias': '[REDACTED]',
      },
    ));
  }

  /// Record a release deployment event.
  void recordReleaseDeployed({
    required String releaseId,
    required String environment,
    required String platform,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.releaseDeployed,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'environment': environment,
        'platform': platform,
      },
    ));
  }

  /// Record a rollout event.
  void recordRolloutEvent({
    required String releaseId,
    required String rolloutId,
    required DeploymentAuditEventType eventType,
    required int percentage,
    String? reason,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: eventType,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'rollout_id': rolloutId,
        'percentage': percentage.toString(),
        if (reason != null) 'reason': reason,
      },
    ));
  }

  /// Record a rollback event.
  void recordRollbackEvent({
    required String releaseId,
    required String rollbackTargetId,
    required String reason,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.rollbackCompleted,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'rollback_target': rollbackTargetId,
        'reason': reason,
      },
    ));
  }

  /// Record an approval event.
  void recordApprovalEvent({
    required String releaseId,
    required String role,
    required String decision,
    required String approverId,
    String? justification,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.approvalSubmitted,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: approverId,
      metadata: {
        'role': role,
        'decision': decision,
        if (justification != null) 'justification': '[REDACTED]',
      },
    ));
  }

  /// Record a flavor validation event.
  void recordFlavorValidation({
    required String releaseId,
    required bool isValid,
    required String expectedFlavor,
    required String actualFlavor,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: isValid
          ? DeploymentAuditEventType.flavorValidationPassed
          : DeploymentAuditEventType.flavorValidationFailed,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'expected_flavor': expectedFlavor,
        'actual_flavor': actualFlavor,
      },
    ));
  }

  /// Record a secret access event (masked).
  void recordSecretAccess({
    required String releaseId,
    required String secretType,
    required String environment,
    String? triggeredBy,
  }) {
    _onAuditEvent(DeploymentAuditEvent(
      eventType: DeploymentAuditEventType.secretAccessed,
      releaseId: releaseId,
      timestamp: DateTime.now(),
      triggeredBy: triggeredBy,
      metadata: {
        'secret_type': '[REDACTED]',
        'environment': environment,
      },
    ));
  }
}

enum DeploymentAuditEventType {
  releaseCreated,
  releaseValidated,
  releaseSigned,
  releaseApproved,
  releaseDeployed,
  rolloutStarted,
  rolloutPaused,
  rolloutResumed,
  rolloutCompleted,
  rollbackInitiated,
  rollbackCompleted,
  flavorValidationPassed,
  flavorValidationFailed,
  signingCompleted,
  signingFailed,
  approvalSubmitted,
  approvalRejected,
  environmentValidationPassed,
  environmentValidationFailed,
  secretAccessed,
  secretLeakDetected,
  whiteLabelValidationPassed,
  whiteLabelValidationFailed,
  complianceCheckPassed,
  complianceCheckFailed,
}

class DeploymentAuditEvent {
  const DeploymentAuditEvent({
    required this.eventType,
    required this.releaseId,
    required this.timestamp,
    this.triggeredBy,
    this.metadata = const {},
  });

  final DeploymentAuditEventType eventType;
  final String releaseId;
  final DateTime timestamp;
  final String? triggeredBy;
  final Map<String, String> metadata;
}
