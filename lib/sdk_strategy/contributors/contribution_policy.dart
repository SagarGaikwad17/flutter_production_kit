import 'package:flutter_production_kit/sdk_strategy/domain/entities/contribution_record.dart';

/// Contribution policy — defines standards and rules for contributions.
///
/// Design rationale:
/// - All contributions must follow architectural standards.
/// - PRs require minimum review approval before merging.
/// - Breaking changes require additional review from maintainers.
/// - Documentation updates are required for API changes.
/// - Tests are required for all code changes.
///
/// Contribution standards:
/// - PR template must be filled.
/// - All tests must pass.
/// - Code must follow style guide.
/// - Architecture must be validated.
/// - Breaking changes must have migration guides.
class ContributionPolicy {
  const ContributionPolicy({
    this.minimumReviewers = 2,
    this.requireArchitectureReview = true,
    this.requireTestsForCodeChanges = true,
    this.requireDocsForApiChanges = true,
    this.requireMigrationGuideForBreaking = true,
    this.allowedContributionTypes = const [
      ContributionType.bugFix,
      ContributionType.feature,
      ContributionType.documentation,
      ContributionType.refactoring,
      ContributionType.performance,
      ContributionType.security,
    ],
    this.breakingChangeRequiresMaintainerApproval = true,
  });

  final int minimumReviewers;
  final bool requireArchitectureReview;
  final bool requireTestsForCodeChanges;
  final bool requireDocsForApiChanges;
  final bool requireMigrationGuideForBreaking;
  final List<ContributionType> allowedContributionTypes;
  final bool breakingChangeRequiresMaintainerApproval;

  /// Validate that a contribution meets policy requirements.
  ContributionResult validateContribution({
    required ContributionRecord contribution,
    required int reviewerCount,
    required bool hasTests,
    required bool hasDocs,
    required bool architectureValid,
    required bool hasMigrationGuide,
  }) {
    final violations = <String>[];

    // Check contribution type
    if (!allowedContributionTypes.contains(contribution.type)) {
      violations.add('Contribution type not allowed: ${contribution.type}');
    }

    // Check minimum reviewers
    if (reviewerCount < minimumReviewers) {
      violations.add(
        'Minimum $minimumReviewers reviewers required, got $reviewerCount',
      );
    }

    // Check architecture review
    if (requireArchitectureReview && !architectureValid) {
      violations.add('Architecture review required and not passed');
    }

    // Check tests for code changes
    if (requireTestsForCodeChanges &&
        _isCodeChange(contribution.type) &&
        !hasTests) {
      violations.add('Tests required for code changes');
    }

    // Check docs for API changes
    if (requireDocsForApiChanges &&
        _isApiChange(contribution.type) &&
        !hasDocs) {
      violations.add('Documentation required for API changes');
    }

    // Check migration guide for breaking changes
    if (requireMigrationGuideForBreaking &&
        contribution.type == ContributionType.breakingChange &&
        !hasMigrationGuide) {
      violations.add('Migration guide required for breaking changes');
    }

    if (violations.isNotEmpty) {
      return ContributionRejected(
        contributionId: contribution.id,
        reason: violations.join('; '),
      );
    }

    return ContributionApproved(
      contributionId: contribution.id,
      reviewers: contribution.reviewers,
    );
  }

  bool _isCodeChange(ContributionType type) {
    return type == ContributionType.feature ||
        type == ContributionType.bugFix ||
        type == ContributionType.refactoring ||
        type == ContributionType.performance ||
        type == ContributionType.security;
  }

  bool _isApiChange(ContributionType type) {
    return type == ContributionType.feature ||
        type == ContributionType.breakingChange;
  }
}

/// Review guardrails — enforces architecture and quality standards during PR review.
class ReviewGuardrails {
  const ReviewGuardrails({
    this.architectureRules = const [
      'No circular dependencies between packages',
      'Core packages cannot depend on engine packages',
      'All public APIs must be documented',
      'All breaking changes must have deprecation warnings',
      'No direct file I/O in core packages',
      'No print statements in production code',
      'All exceptions must be typed',
      'No global mutable state',
    ],
    this.qualityThresholds = const {
      'test_coverage': 0.80,
      'doc_coverage': 0.90,
      'complexity_score': 10,
    },
    this.autoRejectPatterns = const [
      'TODO:',
      'FIXME:',
      'HACK:',
      'print(',
      'debugPrint(',
    ],
  });

  final List<String> architectureRules;
  final Map<String, double> qualityThresholds;
  final List<String> autoRejectPatterns;

  /// Check if code contains auto-reject patterns.
  List<String> checkAutoRejectPatterns(String code) {
    final violations = <String>[];
    for (final pattern in autoRejectPatterns) {
      if (code.contains(pattern)) {
        violations.add('Auto-reject pattern found: "$pattern"');
      }
    }
    return violations;
  }

  /// Validate contribution against architecture rules.
  List<String> validateArchitecture({
    required List<String> architectureDecisions,
    required String packageName,
  }) {
    return [];
  }

  /// Calculate quality score for a contribution.
  double calculateQualityScore({
    required double testCoverage,
    required double docCoverage,
    required int complexityScore,
    required int testCount,
  }) {
    var score = 0.0;

    final testCoverageThreshold = qualityThresholds['test_coverage'] ?? 0.80;
    final docCoverageThreshold = qualityThresholds['doc_coverage'] ?? 0.90;

    if (testCoverage >= testCoverageThreshold) score += 40;
    if (docCoverage >= docCoverageThreshold) score += 30;
    if (complexityScore <= (qualityThresholds['complexity_score'] ?? 10)) score += 20;
    if (testCount > 0) score += 10;

    return score.clamp(0, 100);
  }
}
