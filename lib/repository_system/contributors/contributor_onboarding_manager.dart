import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Contributor onboarding manager — guides new contributors through their first contributions.
///
/// Design rationale:
/// - First-time contributors need clear, step-by-step guidance.
/// - Onboarding reduces friction and increases contributor retention.
/// - "Good first issue" labels help newcomers find appropriate tasks.
/// - Mentorship pairing accelerates learning and confidence.
///
/// Onboarding flow:
/// 1. Read CONTRIBUTING.md and code of conduct.
/// 2. Set up local development environment.
/// 3. Run tests and verify setup.
/// 4. Pick a "good first issue".
/// 5. Create a branch and implement the fix.
/// 6. Submit PR with clear description.
/// 7. Respond to review feedback.
/// 8. Celebrate merged PR!
class ContributorOnboardingManager {
  const ContributorOnboardingManager({
    required IContributorRepository contributorRepository,
    this.onboardingSteps = const [
      'read_contributing_guide',
      'setup_environment',
      'run_tests',
      'pick_first_issue',
      'create_branch',
      'implement_fix',
      'submit_pr',
      'respond_to_review',
      'celebrate_merge',
    ],
    this.firstIssueLabels = const [
      'good-first-issue',
      'help-wanted',
      'beginner-friendly',
    ],
    this.mentorshipEnabled = true,
  }) : _contributorRepository = contributorRepository;

  final IContributorRepository _contributorRepository;
  final List<String> onboardingSteps;
  final List<String> firstIssueLabels;
  final bool mentorshipEnabled;

  /// Start onboarding for a new contributor.
  Future<RepoResult> startOnboarding({
    required String contributorId,
    required List<String> completedSteps,
  }) async {
    final missingSteps = onboardingSteps
        .where((step) => !completedSteps.contains(step))
        .toList();

    if (missingSteps.isNotEmpty) {
      throw ContributorOnboardingFailedException(
        message: 'Onboarding incomplete',
        contributorId: contributorId,
        missingSteps: missingSteps,
      );
    }

    // Mark contributor as onboarded
    final contributor = ContributorState(
      id: contributorId,
      status: ContributorStatus.contributor,
      joinedAt: DateTime.now(),
    );
    await _contributorRepository.saveContributor(contributor);

    // Find first issues for the contributor
    final firstIssues = await _findFirstIssues();

    return ContributorOnboardingReady(
      operation: 'start_onboarding',
      onboardingSteps: onboardingSteps,
      firstIssues: firstIssues,
    );
  }

  /// Update contributor reputation based on activity.
  Future<void> updateReputation({
    required String contributorId,
    required String activity,
  }) async {
    int scoreChange = 0;

    switch (activity) {
      case 'pr_merged':
        scoreChange += 10;
        break;
      case 'pr_reviewed':
        scoreChange += 5;
        break;
      case 'issue_reported':
        scoreChange += 2;
        break;
      case 'issue_triaged':
        scoreChange += 3;
        break;
      case 'documentation_updated':
        scoreChange += 5;
        break;
      case 'bug_fixed':
        scoreChange += 8;
        break;
      case 'feature_implemented':
        scoreChange += 12;
        break;
    }

    await _contributorRepository.updateReputation(contributorId, scoreChange);
  }

  /// Check contributor trust level.
  Future<RepoResult> checkTrustLevel(String contributorId) async {
    final contributor = await _contributorRepository.getContributor(contributorId);

    if (contributor == null) {
      return ContributorOnboardingReady(
        operation: 'check_trust_level',
        onboardingSteps: [],
        firstIssues: [],
      );
    }

    if (contributor.isTrusted) {
      return PubDevPublishSafe(
        operation: 'check_trust_level',
        packageName: contributorId,
        score: contributor.reputationScore,
        checks: ['Trusted contributor'],
      );
    }

    return MaintainerOverloadRiskDetected(
      operation: 'check_trust_level',
      riskLevel: contributor.isNew ? 'new' : 'growing',
      indicators: [
        'Reputation: ${contributor.reputationScore}',
        'Merged PRs: ${contributor.mergedPRs}',
        'Status: ${contributor.status.name}',
      ],
      recommendations: [
        'Continue contributing to increase trust level',
        'Participate in code reviews',
        'Help triage issues',
      ],
    );
  }

  /// Find "good first issues" for new contributors.
  Future<List<String>> _findFirstIssues() async {
    // In production, query issues with firstIssueLabels
    return [
      '#123: Fix typo in README',
      '#145: Add example for auth module',
      '#167: Improve error message for network failures',
    ];
  }

  /// Generate onboarding checklist for a contributor.
  Map<String, bool> generateChecklist(String contributorId) {
    return {
      for (final step in onboardingSteps) step: false,
    };
  }

  /// Check if contributor is eligible for mentorship.
  bool isEligibleForMentorship({
    required ContributorState contributor,
  }) {
    if (!mentorshipEnabled) return false;
    return contributor.isNew && contributor.status == ContributorStatus.newcomer;
  }
}
