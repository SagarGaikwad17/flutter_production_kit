/// Repository system exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific repository/maintenance failure mode.
/// - Exceptions include actionable guidance for resolution.
/// - No sensitive data in exception messages.
sealed class RepoException implements Exception {
  const RepoException({required this.message, this.guidance});
  final String message;
  final String? guidance;

  @override
  String toString() =>
      'RepoException: $message${guidance != null ? ' (guidance: $guidance)' : ''}';
}

/// Monorepo structure invalid — repository structure violates boundaries.
final class MonorepoStructureInvalidException extends RepoException {
  const MonorepoStructureInvalidException({
    required super.message,
    required this.violations,
    super.guidance = 'Review package boundary rules and fix violations',
  });
  final List<String> violations;
}

/// Release governance failed — release did not pass governance checks.
final class ReleaseGovernanceFailedException extends RepoException {
  const ReleaseGovernanceFailedException({
    required super.message,
    required this.packageName,
    required this.failedChecks,
    super.guidance = 'Fix failed governance checks before releasing',
  });
  final String packageName;
  final List<String> failedChecks;
}

/// PR architecture violation — PR violates architecture rules.
final class PRArchitectureViolationException extends RepoException {
  const PRArchitectureViolationException({
    required super.message,
    required this.prNumber,
    required this.violations,
    super.guidance = 'Fix architecture violations before merging',
  });
  final int prNumber;
  final List<String> violations;
}

/// Issue triage failed — issue could not be triaged automatically.
final class IssueTriageFailedException extends RepoException {
  const IssueTriageFailedException({
    required super.message,
    required this.issueNumber,
    super.guidance = 'Manually triage the issue and assign appropriate labels',
  });
  final int issueNumber;
}

/// Maintainer overload detected — maintainer workload is unsustainable.
final class MaintainerOverloadException extends RepoException {
  const MaintainerOverloadException({
    required super.message,
    required this.currentLoad,
    required this.maxCapacity,
    super.guidance = 'Delegate tasks to community or reduce scope',
  });
  final int currentLoad;
  final int maxCapacity;
}

/// Changelog validation failed — changelog does not meet standards.
final class ChangelogValidationFailedException extends RepoException {
  const ChangelogValidationFailedException({
    required super.message,
    required this.packageName,
    required this.missingEntries,
    super.guidance = 'Add missing changelog entries following the standard format',
  });
  final String packageName;
  final List<String> missingEntries;
}

/// Package boundary violation — package dependency violates monorepo rules.
final class PackageBoundaryViolationException extends RepoException {
  const PackageBoundaryViolationException({
    required super.message,
    required this.sourcePackage,
    required this.targetPackage,
    super.guidance = 'Restructure package dependencies to follow boundary rules',
  });
  final String sourcePackage;
  final String targetPackage;
}

/// Contributor onboarding failed — contributor could not be onboarded.
final class ContributorOnboardingFailedException extends RepoException {
  const ContributorOnboardingFailedException({
    required super.message,
    required this.contributorId,
    required this.missingSteps,
    super.guidance = 'Complete all onboarding steps before contributing',
  });
  final String contributorId;
  final List<String> missingSteps;
}

/// Roadmap update failed — roadmap could not be updated.
final class RoadmapUpdateFailedException extends RepoException {
  const RoadmapUpdateFailedException({
    required super.message,
    required this.failedItems,
    super.guidance = 'Review roadmap items and retry the update',
  });
  final List<String> failedItems;
}
