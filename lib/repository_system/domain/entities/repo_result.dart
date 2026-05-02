/// Repository result — explicit outcome of any repository operation.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No bool-only checks — each result carries context and guidance.
/// - CI/CD pipelines can pattern-match to determine pass/fail.
/// - Governance flows can branch based on result type.
///
/// Outcomes:
/// - RepositoryLaunchValidated: repository is ready for public launch.
/// - ContributorOnboardingReady: contributor onboarding is complete.
/// - PRBlockedByArchitectureViolation: PR violates architecture rules.
/// - ReleaseGovernanceApproved: release passed governance checks.
/// - PubDevPublishSafe: package is safe to publish to pub.dev.
/// - MaintainerOverloadRiskDetected: maintainer workload is unsustainable.
/// - IssueTriageCompleted: issue has been triaged and routed.
/// - MonorepoValidationPassed: monorepo structure is valid.
/// - ChangelogValidationPassed: changelog meets standards.
/// - RoadmapPublishedSuccessfully: public roadmap is published.
sealed class RepoResult {
  const RepoResult({required this.operation});
  final String operation;

  bool get isSuccess =>
      this is RepositoryLaunchValidated ||
      this is ContributorOnboardingReady ||
      this is ReleaseGovernanceApproved ||
      this is PubDevPublishSafe ||
      this is IssueTriageCompleted ||
      this is MonorepoValidationPassed ||
      this is ChangelogValidationPassed ||
      this is RoadmapPublishedSuccessfully;
}

/// Repository launch validated — repo is ready for public launch.
final class RepositoryLaunchValidated extends RepoResult {
  const RepositoryLaunchValidated({
    required super.operation,
    required this.checks,
    this.warnings = const [],
  });
  final List<String> checks;
  final List<String> warnings;
}

/// Contributor onboarding ready — onboarding is complete.
final class ContributorOnboardingReady extends RepoResult {
  const ContributorOnboardingReady({
    required super.operation,
    required this.onboardingSteps,
    this.firstIssues = const [],
  });
  final List<String> onboardingSteps;
  final List<String> firstIssues;
}

/// PR blocked by architecture violation.
final class PRBlockedByArchitectureViolation extends RepoResult {
  const PRBlockedByArchitectureViolation({
    required super.operation,
    required this.prNumber,
    required this.violations,
    this.blocker,
  });
  final int prNumber;
  final List<String> violations;
  final String? blocker;
}

/// Release governance approved.
final class ReleaseGovernanceApproved extends RepoResult {
  const ReleaseGovernanceApproved({
    required super.operation,
    required this.packageName,
    required this.version,
    this.approvers = const [],
  });
  final String packageName;
  final String version;
  final List<String> approvers;
}

/// Pub.dev publish safe.
final class PubDevPublishSafe extends RepoResult {
  const PubDevPublishSafe({
    required super.operation,
    required this.packageName,
    this.score,
    this.checks = const [],
  });
  final String packageName;
  final int? score;
  final List<String> checks;
}

/// Maintainer overload risk detected.
final class MaintainerOverloadRiskDetected extends RepoResult {
  const MaintainerOverloadRiskDetected({
    required super.operation,
    required this.riskLevel,
    required this.indicators,
    this.recommendations = const [],
  });
  final String riskLevel;
  final List<String> indicators;
  final List<String> recommendations;
}

/// Issue triage completed.
final class IssueTriageCompleted extends RepoResult {
  const IssueTriageCompleted({
    required super.operation,
    required this.issueNumber,
    required this.severity,
    required this.labels,
    this.assignee,
  });
  final int issueNumber;
  final String severity;
  final List<String> labels;
  final String? assignee;
}

/// Monorepo validation passed.
final class MonorepoValidationPassed extends RepoResult {
  const MonorepoValidationPassed({
    required super.operation,
    required this.packageCount,
    this.warnings = const [],
  });
  final int packageCount;
  final List<String> warnings;
}

/// Changelog validation passed.
final class ChangelogValidationPassed extends RepoResult {
  const ChangelogValidationPassed({
    required super.operation,
    required this.packageName,
    this.entries = const [],
  });
  final String packageName;
  final List<String> entries;
}

/// Roadmap published successfully.
final class RoadmapPublishedSuccessfully extends RepoResult {
  const RoadmapPublishedSuccessfully({
    required super.operation,
    required this.items,
    this.lastUpdated,
  });
  final List<String> items;
  final DateTime? lastUpdated;
}

/// PR state — represents a pull request with review status.
class PRState {
  const PRState({
    required this.number,
    required this.packageName,
    required this.status,
    required this.author,
    required this.createdAt,
    this.title,
    this.labels = const [],
    this.reviewers = const [],
    this.checks = const {},
    this.architectureViolations = const [],
    this.isBreakingChange = false,
    this.mergedAt,
    this.closedAt,
  });

  final int number;
  final String packageName;
  final PRStatus status;
  final String author;
  final DateTime createdAt;
  final String? title;
  final List<String> labels;
  final List<String> reviewers;
  final Map<String, bool> checks;
  final List<String> architectureViolations;
  final bool isBreakingChange;
  final DateTime? mergedAt;
  final DateTime? closedAt;

  bool get isApproved => status == PRStatus.approved;
  bool get isMerged => status == PRStatus.merged;
  bool get isBlocked => status == PRStatus.blocked;
  bool get allChecksPassed => checks.values.every((v) => v);
  bool get hasArchitectureViolations => architectureViolations.isNotEmpty;
}

enum PRStatus {
  draft,
  open,
  underReview,
  approved,
  blocked,
  merged,
  closed,
}

/// Issue state — represents a GitHub issue with triage status.
class IssueState {
  const IssueState({
    required this.number,
    required this.type,
    required this.severity,
    required this.status,
    required this.author,
    required this.createdAt,
    this.title,
    this.labels = const [],
    this.assignee,
    this.package,
    this.isDuplicate = false,
    this.duplicateOf,
    this.closedAt,
  });

  final int number;
  final IssueType type;
  final IssueSeverity severity;
  final IssueStatus status;
  final String author;
  final DateTime createdAt;
  final String? title;
  final List<String> labels;
  final String? assignee;
  final String? package;
  final bool isDuplicate;
  final int? duplicateOf;
  final DateTime? closedAt;

  bool get isCritical => severity == IssueSeverity.critical;
  bool get isOpen => status == IssueStatus.open;
  bool get isTriageNeeded => status == IssueStatus.triageNeeded;
}

enum IssueType {
  bug,
  feature,
  documentation,
  question,
  maintenance,
}

enum IssueSeverity {
  critical,
  high,
  medium,
  low,
}

enum IssueStatus {
  triageNeeded,
  open,
  inProgress,
  review,
  closed,
  duplicate,
  wontfix,
}

/// Contributor state — tracks a contributor's activity and reputation.
class ContributorState {
  const ContributorState({
    required this.id,
    required this.status,
    this.joinedAt,
    this.prCount = 0,
    this.issueCount = 0,
    this.reviewCount = 0,
    this.mergedPRs = 0,
    this.reputationScore = 0,
    this.areasOfExpertise = const [],
    this.lastActiveAt,
  });

  final String id;
  final ContributorStatus status;
  final DateTime? joinedAt;
  final int prCount;
  final int issueCount;
  final int reviewCount;
  final int mergedPRs;
  final int reputationScore;
  final List<String> areasOfExpertise;
  final DateTime? lastActiveAt;

  bool get isNew => prCount < 3;
  bool get isTrusted => reputationScore >= 50;
  bool get isActive {
    final last = lastActiveAt;
    return last != null && DateTime.now().difference(last).inDays < 30;
  }
}

enum ContributorStatus {
  newcomer,
  contributor,
  regular,
  maintainer,
  core,
}

/// Roadmap item — represents a public roadmap entry.
class RoadmapItem {
  const RoadmapItem({
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.targetDate,
    this.package,
    this.assignee,
  });

  final String title;
  final RoadmapStatus status;
  final RoadmapPriority priority;
  final String? description;
  final DateTime? targetDate;
  final String? package;
  final String? assignee;
}

enum RoadmapStatus {
  planned,
  inProgress,
  completed,
  deferred,
}

enum RoadmapPriority {
  critical,
  high,
  medium,
  low,
}
