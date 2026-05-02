/// Release engineering exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific release/deployment failure mode.
/// - [ReleaseException] is the base for all release errors.
/// - NO sensitive data in exception messages (no keys, no passwords).
/// - Exceptions are actionable — include recovery guidance.
/// - Critical failures (flavor mismatch, secret leak) are explicitly typed.
sealed class ReleaseException implements Exception {
  const ReleaseException({required this.message, this.recoveryAction});
  final String message;
  final String? recoveryAction;

  @override
  String toString() =>
      'ReleaseException: $message${recoveryAction != null ? ' (recovery: $recoveryAction)' : ''}';
}

/// Wrong flavor release — production release built with staging configs.
final class WrongFlavorReleaseException extends ReleaseException {
  const WrongFlavorReleaseException({
    required super.message,
    required this.expectedFlavor,
    required this.actualFlavor,
    required this.environment,
    super.recoveryAction = 'Abort release and rebuild with correct flavor',
  });
  final String expectedFlavor;
  final String actualFlavor;
  final String environment;
}

/// White-label client mismatch — Client A received Client B's branded app.
final class WhiteLabelClientMismatchException extends ReleaseException {
  const WhiteLabelClientMismatchException({
    required super.message,
    required this.expectedClientId,
    required this.actualClientId,
    super.recoveryAction = 'Verify white-label configuration and rebuild',
  });
  final String expectedClientId;
  final String actualClientId;
}

/// Signing failure — artifact could not be signed.
final class SigningFailureException extends ReleaseException {
  const SigningFailureException({
    required super.message,
    this.platform,
    this.environment,
    super.recoveryAction = 'Verify signing credentials and retry',
  });
  final String? platform;
  final String? environment;
}

/// Signing key expired.
final class SigningKeyExpiredException extends ReleaseException {
  const SigningKeyExpiredException({
    required super.message,
    required this.keyAlias,
    required this.expiredAt,
    super.recoveryAction = 'Rotate signing key and re-sign artifact',
  });
  final String keyAlias;
  final DateTime expiredAt;
}

/// Secret access denied.
final class SecretAccessDeniedException extends ReleaseException {
  const SecretAccessDeniedException({
    required super.message,
    required this.requestedSecret,
    super.recoveryAction = 'Verify CI/CD secret permissions',
  });
  final String requestedSecret;
}

/// Secret leak detected.
final class SecretLeakDetectedException extends ReleaseException {
  const SecretLeakDetectedException({
    required super.message,
    required this.secretType,
    super.recoveryAction = 'Rotate compromised secret immediately and audit logs',
  });
  final String secretType;
}

/// Missing approval.
final class MissingApprovalException extends ReleaseException {
  const MissingApprovalException({
    required super.message,
    required this.missingRoles,
    required this.releaseId,
    super.recoveryAction = 'Obtain required approvals before proceeding',
  });
  final List<String> missingRoles;
  final String releaseId;
}

/// Compliance violation.
final class ComplianceViolationException extends ReleaseException {
  const ComplianceViolationException({
    required super.message,
    required this.violation,
    this.regulation,
    super.recoveryAction = 'Resolve compliance issue before release',
  });
  final String violation;
  final String? regulation;
}

/// Environment mismatch.
final class EnvironmentMismatchException extends ReleaseException {
  const EnvironmentMismatchException({
    required super.message,
    required this.expectedEnvironment,
    required this.actualEnvironment,
    super.recoveryAction = 'Verify target environment configuration',
  });
  final String expectedEnvironment;
  final String actualEnvironment;
}

/// Partial release failure.
final class PartialReleaseFailureException extends ReleaseException {
  const PartialReleaseFailureException({
    required super.message,
    required this.succeededPlatforms,
    required this.failedPlatforms,
    super.recoveryAction = 'Retry failed platforms or rollback successful ones',
  });
  final List<String> succeededPlatforms;
  final List<String> failedPlatforms;
}

/// Rollback failure.
final class RollbackFailureException extends ReleaseException {
  const RollbackFailureException({
    required super.message,
    required this.releaseId,
    required this.rollbackTargetId,
    super.recoveryAction = 'Verify rollback artifact integrity and retry',
  });
  final String releaseId;
  final String rollbackTargetId;
}

/// Release not found.
final class ReleaseNotFoundException extends ReleaseException {
  const ReleaseNotFoundException({
    required super.message,
    this.releaseId,
    super.recoveryAction = 'Verify release ID and retry',
  });
  final String? releaseId;
}

/// Hotfix under pressure — emergency release with elevated risk.
final class EmergencyReleaseException extends ReleaseException {
  const EmergencyReleaseException({
    required super.message,
    required this.releaseId,
    required this.severity,
    super.recoveryAction = 'Proceed with emergency release; post-release audit required',
  });
  final String releaseId;
  final String severity;
}

/// Store rejection.
final class StoreRejectionException extends ReleaseException {
  const StoreRejectionException({
    required super.message,
    required this.store,
    required this.reason,
    super.recoveryAction = 'Address store rejection reason and resubmit',
  });
  final String store;
  final String reason;
}
