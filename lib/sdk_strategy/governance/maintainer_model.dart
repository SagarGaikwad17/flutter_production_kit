/// Maintainer model — defines the governance structure for the SDK ecosystem.
///
/// Design rationale:
/// - Maintainers have different roles and responsibilities.
/// - Architecture decisions require maintainer consensus.
/// - Release approval requires maintainer signoff.
/// - Contributor onboarding is managed by maintainers.
///
/// Maintainer roles:
/// - Core maintainer — full access to all packages, release authority.
/// - Package maintainer — access to specific packages.
/// - Reviewer — can approve/review PRs but cannot merge.
/// - Contributor — can submit PRs but cannot approve.
///
/// Governance model:
/// - RFC process for major architectural changes.
/// - Voting for breaking changes.
/// - Release cadence is maintained by core maintainers.
/// - Deprecation decisions require consensus.
class MaintainerModel {
  const MaintainerModel({
    this.maintainerRoles = const {
      'core': ['all_packages', 'release', 'deprecation', 'architecture'],
      'package': ['assigned_packages', 'review', 'approve'],
      'reviewer': ['review', 'comment'],
      'contributor': ['submit_pr', 'comment'],
    },
    this.releaseApprovalRequiresCoreCount = 2,
    this.architectureRfcRequired = true,
    this.breakingChangeVotingRequired = true,
    this.minVotingPeriod = const Duration(days: 7),
  });

  final Map<String, List<String>> maintainerRoles;
  final int releaseApprovalRequiresCoreCount;
  final bool architectureRfcRequired;
  final bool breakingChangeVotingRequired;
  final Duration minVotingPeriod;

  /// Check if a maintainer has permission for an action.
  bool hasPermission(String role, String action) {
    final permissions = maintainerRoles[role];
    return permissions != null && permissions.contains(action);
  }

  /// Get required approvers for a release.
  List<String> getRequiredApprovers({
    required bool isBreaking,
    required bool isMajorRelease,
  }) {
    if (isMajorRelease || isBreaking) {
      return ['core'];
    }
    return ['package', 'core'];
  }

  /// Validate that a release has sufficient maintainer approval.
  bool validateReleaseApproval({
    required List<String> approverRoles,
    required bool isBreaking,
  }) {
    final coreApprovers = approverRoles.where((r) => r == 'core').length;
    return coreApprovers >= releaseApprovalRequiresCoreCount;
  }
}

/// Governance result — outcome of a governance decision.
sealed class GovernanceResult {
  const GovernanceResult({required this.action});
  final String action;

  bool get isApproved => this is GovernanceApproved;
}

/// Governance action approved.
final class GovernanceApproved extends GovernanceResult {
  const GovernanceApproved({
    required super.action,
    required this.approvers,
    this.votes,
  });
  final List<String> approvers;
  final Map<String, String>? votes;
}

/// Governance action rejected.
final class GovernanceRejected extends GovernanceResult {
  const GovernanceRejected({
    required super.action,
    required this.reason,
    this.rejectedBy,
  });
  final String reason;
  final String? rejectedBy;
}

/// RFC required for architecture change.
final class ArchitectureRfcRequired extends GovernanceResult {
  const ArchitectureRfcRequired({
    required super.action,
    required this.rfcTemplate,
    this.votingPeriod,
  });
  final String rfcTemplate;
  final Duration? votingPeriod;
}
