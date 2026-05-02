/// Contribution record — represents a contribution to the SDK ecosystem.
///
/// Design rationale:
/// - Contributions are tracked for quality and compliance.
/// - Each contribution has a type, status, and review outcome.
/// - Architecture violations are flagged automatically.
/// - Contributor reputation is tracked over time.
class ContributionRecord {
  const ContributionRecord({
    required this.id,
    required this.packageName,
    required this.type,
    required this.status,
    required this.contributorId,
    required this.createdAt,
    this.title,
    this.description,
    this.reviewers = const [],
    this.approvalStatus = ApprovalStatus.pending,
    this.architectureViolations = const [],
    this.qualityScore,
    this.mergedAt,
    this.closedAt,
  });

  final String id;
  final String packageName;
  final ContributionType type;
  final ContributionStatus status;
  final String contributorId;
  final DateTime createdAt;
  final String? title;
  final String? description;
  final List<String> reviewers;
  final ApprovalStatus approvalStatus;
  final List<String> architectureViolations;
  final int? qualityScore;
  final DateTime? mergedAt;
  final DateTime? closedAt;

  bool get isMerged => status == ContributionStatus.merged;
  bool get isRejected => status == ContributionStatus.rejected;
  bool get hasArchitectureViolations => architectureViolations.isNotEmpty;
  bool get isApproved => approvalStatus == ApprovalStatus.approved;
}

enum ContributionType {
  bugFix,
  feature,
  documentation,
  refactoring,
  performance,
  security,
  breakingChange,
}

enum ContributionStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  merged,
  closed,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
  changesRequested,
}

/// Contributor architecture violation — detected during PR review.
class ContributorArchitectureViolation {
  const ContributorArchitectureViolation({
    required this.rule,
    required this.description,
    required this.severity,
    this.filePath,
    this.lineNumber,
  });

  final String rule;
  final String description;
  final ArchitectureViolationSeverity severity;
  final String? filePath;
  final int? lineNumber;
}

enum ArchitectureViolationSeverity {
  warning,
  error,
  critical,
}

/// Contribution result — outcome of a contribution review.
sealed class ContributionResult {
  const ContributionResult({required this.contributionId});
  final String contributionId;

  bool get isApproved => this is ContributionApproved;
}

/// Contribution approved for merge.
final class ContributionApproved extends ContributionResult {
  const ContributionApproved({
    required super.contributionId,
    required this.reviewers,
    this.qualityScore,
    this.comments = const [],
  });
  final List<String> reviewers;
  final int? qualityScore;
  final List<String> comments;
}

/// Contribution blocked by architecture violation.
final class ContributorArchitectureViolationDetected extends ContributionResult {
  const ContributorArchitectureViolationDetected({
    required super.contributionId,
    required this.violations,
    this.blocker,
  });
  final List<ContributorArchitectureViolation> violations;
  final String? blocker;
}

/// Contribution rejected.
final class ContributionRejected extends ContributionResult {
  const ContributionRejected({
    required super.contributionId,
    required this.reason,
    this.reviewer,
  });
  final String reason;
  final String? reviewer;
}

/// Contributor onboarding validated.
final class ContributorOnboardingValidated extends ContributionResult {
  const ContributorOnboardingValidated({
    required super.contributionId,
    required this.contributorId,
    this.requiredReadings = const [],
    this.requiredSetup = const [],
  });
  final String contributorId;
  final List<String> requiredReadings;
  final List<String> requiredSetup;
}
