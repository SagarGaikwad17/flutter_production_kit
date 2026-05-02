/// Release result — explicit outcome of a release operation.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No bool-only checks — each result carries context.
/// - UI layer can pattern-match to show correct messaging.
/// - Audit layer can log the exact release decision.
///
/// Outcomes:
/// - ReleaseValidated: release passed all validation gates.
/// - BlockedByFlavorMismatch: flavor validation failed.
/// - BlockedBySigningFailure: signing process failed.
/// - BlockedByApprovalMissing: required approvals not obtained.
/// - BlockedByComplianceViolation: compliance check failed.
/// - BlockedByEnvironmentMismatch: environment validation failed.
/// - WhiteLabelVerificationFailed: wrong white-label client detected.
/// - RollbackTriggered: release rolled back due to failure.
/// - StagedRolloutPaused: rollout paused for health check.
/// - PartialReleaseFailure: one platform failed, another succeeded.
/// - ReleaseCompleted: release fully deployed.
sealed class ReleaseResult {
  const ReleaseResult({required this.releaseId});
  final String releaseId;

  bool get isSuccess => this is ReleaseCompleted || this is ReleaseValidated;
  bool get isBlocked => !isSuccess && this is! ReleaseCompleted;
}

/// Release passed all validation gates.
final class ReleaseValidated extends ReleaseResult {
  const ReleaseValidated({
    required super.releaseId,
    required this.flavor,
    required this.checksum,
    this.warnings = const [],
  });
  final String flavor;
  final String checksum;
  final List<String> warnings;
}

/// Release fully deployed.
final class ReleaseCompleted extends ReleaseResult {
  const ReleaseCompleted({
    required super.releaseId,
    required this.deployedAt,
    required this.rolloutPercentage,
  });
  final DateTime deployedAt;
  final int rolloutPercentage;
}

/// Blocked by flavor mismatch.
final class BlockedByFlavorMismatch extends ReleaseResult {
  const BlockedByFlavorMismatch({
    required super.releaseId,
    required this.expectedFlavor,
    required this.actualFlavor,
    this.environment,
  });
  final String expectedFlavor;
  final String actualFlavor;
  final String? environment;
}

/// Blocked by signing failure.
final class BlockedBySigningFailure extends ReleaseResult {
  const BlockedBySigningFailure({
    required super.releaseId,
    required this.reason,
    this.platform,
  });
  final String reason;
  final String? platform;
}

/// Blocked by missing approval.
final class BlockedByApprovalMissing extends ReleaseResult {
  const BlockedByApprovalMissing({
    required super.releaseId,
    required this.missingRoles,
    this.blocker,
  });
  final List<String> missingRoles;
  final String? blocker;
}

/// Blocked by compliance violation.
final class BlockedByComplianceViolation extends ReleaseResult {
  const BlockedByComplianceViolation({
    required super.releaseId,
    required this.violation,
    this.regulation,
  });
  final String violation;
  final String? regulation;
}

/// Blocked by environment mismatch.
final class BlockedByEnvironmentMismatch extends ReleaseResult {
  const BlockedByEnvironmentMismatch({
    required super.releaseId,
    required this.expectedEnvironment,
    required this.actualEnvironment,
  });
  final String expectedEnvironment;
  final String? actualEnvironment;
}

/// White-label verification failed.
final class WhiteLabelVerificationFailed extends ReleaseResult {
  const WhiteLabelVerificationFailed({
    required super.releaseId,
    required this.expectedClientId,
    required this.actualClientId,
    this.brandingMismatch,
  });
  final String expectedClientId;
  final String actualClientId;
  final String? brandingMismatch;
}

/// Rollback triggered due to failure.
final class RollbackTriggered extends ReleaseResult {
  const RollbackTriggered({
    required super.releaseId,
    required this.rollbackTargetId,
    required this.reason,
    this.triggeredBy,
    this.triggeredAt,
  });
  final String rollbackTargetId;
  final String reason;
  final String? triggeredBy;
  final DateTime? triggeredAt;
}

/// Staged rollout paused for health check.
final class StagedRolloutPaused extends ReleaseResult {
  const StagedRolloutPaused({
    required super.releaseId,
    required this.currentPercentage,
    required this.reason,
    this.pausedAt,
  });
  final int currentPercentage;
  final String reason;
  final DateTime? pausedAt;
}

/// Partial release failure — one platform failed.
final class PartialReleaseFailure extends ReleaseResult {
  const PartialReleaseFailure({
    required super.releaseId,
    required this.succeededPlatforms,
    required this.failedPlatforms,
    required this.failureReasons,
  });
  final List<String> succeededPlatforms;
  final List<String> failedPlatforms;
  final Map<String, String> failureReasons;
}
