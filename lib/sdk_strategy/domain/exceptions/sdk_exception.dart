/// SDK strategy exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific SDK packaging/publishing failure mode.
/// - NO sensitive data in exception messages.
/// - Exceptions are actionable — include recovery guidance.
sealed class SDKException implements Exception {
  const SDKException({required this.message, this.recoveryAction});
  final String message;
  final String? recoveryAction;

  @override
  String toString() =>
      'SDKException: $message${recoveryAction != null ? ' (recovery: $recoveryAction)' : ''}';
}

/// Package boundary violation — a package depends on a forbidden package.
final class PackageBoundaryViolationException extends SDKException {
  const PackageBoundaryViolationException({
    required super.message,
    required this.sourcePackage,
    required this.targetPackage,
    required this.violationType,
    super.recoveryAction = 'Remove the forbidden dependency or restructure package boundaries',
  });
  final String sourcePackage;
  final String targetPackage;
  final String violationType;
}

/// Breaking change without migration guide.
final class BreakingChangeWithoutMigrationException extends SDKException {
  const BreakingChangeWithoutMigrationException({
    required super.message,
    required this.packageName,
    required this.version,
    required this.breakingChanges,
    super.recoveryAction = 'Create migration guide before publishing breaking changes',
  });
  final String packageName;
  final String version;
  final List<String> breakingChanges;
}

/// Semantic versioning violation.
final class SemverViolationException extends SDKException {
  const SemverViolationException({
    required super.message,
    required this.packageName,
    required this.currentVersion,
    required this.proposedVersion,
    super.recoveryAction = 'Adjust version number to match semantic versioning rules',
  });
  final String packageName;
  final String currentVersion;
  final String proposedVersion;
}

/// Dependency graph violation.
final class DependencyGraphViolationException extends SDKException {
  const DependencyGraphViolationException({
    required super.message,
    required this.packageName,
    required this.violation,
    super.recoveryAction = 'Resolve dependency graph violation before publishing',
  });
  final String packageName;
  final String violation;
}

/// Pub.dev publishing blocked.
final class PubDevPublishingBlockedException extends SDKException {
  const PubDevPublishingBlockedException({
    required super.message,
    required this.packageName,
    required this.blockingIssues,
    super.recoveryAction = 'Resolve blocking issues before publishing to pub.dev',
  });
  final String packageName;
  final List<String> blockingIssues;
}

/// Contributor architecture violation.
final class ContributorArchitectureViolationException extends SDKException {
  const ContributorArchitectureViolationException({
    required super.message,
    required this.contributionId,
    required this.violations,
    super.recoveryAction = 'Fix architecture violations before merging',
  });
  final String contributionId;
  final List<String> violations;
}

/// Migration failure.
final class MigrationFailureException extends SDKException {
  const MigrationFailureException({
    required super.message,
    required this.packageName,
    required this.fromVersion,
    required this.toVersion,
    required this.failedSteps,
    super.recoveryAction = 'Follow migration guide or rollback to previous version',
  });
  final String packageName;
  final String fromVersion;
  final String toVersion;
  final List<String> failedSteps;
}

/// Documentation gap detected.
final class DocumentationGapException extends SDKException {
  const DocumentationGapException({
    required super.message,
    required this.packageName,
    required this.missingDocs,
    super.recoveryAction = 'Create missing documentation before publishing',
  });
  final String packageName;
  final List<String> missingDocs;
}

/// Enterprise readiness failure.
final class EnterpriseReadinessFailureException extends SDKException {
  const EnterpriseReadinessFailureException({
    required super.message,
    required this.packageName,
    required this.failedChecks,
    super.recoveryAction = 'Address failed checks before claiming enterprise readiness',
  });
  final String packageName;
  final List<String> failedChecks;
}

/// Package deprecation violation.
final class PackageDeprecationViolationException extends SDKException {
  const PackageDeprecationViolationException({
    required super.message,
    required this.packageName,
    required this.version,
    required this.deprecationDate,
    required this.endOfLifeDate,
    super.recoveryAction = 'Ensure deprecation notice period is at least 6 months',
  });
  final String packageName;
  final String version;
  final DateTime deprecationDate;
  final DateTime endOfLifeDate;
}
