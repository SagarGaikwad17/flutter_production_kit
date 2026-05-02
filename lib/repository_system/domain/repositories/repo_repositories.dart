import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';

/// Repository interface for repository structure data access.
abstract class IRepoStructureRepository {
  Future<List<String>> getPackages();
  Future<Map<String, List<String>>> getDependencyGraph();
  Future<void> savePackageBoundary(String package, List<String> allowedDeps);
  Future<List<String>> getPackageBoundary(String package);
}

/// Repository interface for PR data access.
abstract class IPRRepository {
  Future<PRState?> getPR(int number);
  Future<List<PRState>> getOpenPRs({String? package});
  Future<void> savePR(PRState pr);
  Future<void> updatePRStatus(int number, PRStatus status);
  Future<Map<String, int>> getPRMetrics({Duration? period});
}

/// Repository interface for issue data access.
abstract class IIssueRepository {
  Future<IssueState?> getIssue(int number);
  Future<List<IssueState>> getOpenIssues({String? package, String? severity});
  Future<void> saveIssue(IssueState issue);
  Future<void> updateIssueStatus(int number, IssueStatus status);
  Future<Map<String, int>> getIssueMetrics({Duration? period});
}

/// Repository interface for contributor data access.
abstract class IContributorRepository {
  Future<ContributorState?> getContributor(String id);
  Future<List<ContributorState>> getActiveContributors();
  Future<void> saveContributor(ContributorState contributor);
  Future<void> updateReputation(String id, int scoreChange);
}

/// Repository interface for release governance data access.
abstract class IReleaseGovernanceRepository {
  Future<Map<String, bool>> getGovernanceChecks(String packageName, String version);
  Future<void> recordGovernanceResult({
    required String packageName,
    required String version,
    required bool passed,
    required List<String> checks,
    required List<String> approvers,
  });
  Future<List<String>> getRequiredApprovers(String packageName);
}

/// Repository interface for changelog data access.
abstract class IChangelogRepository {
  Future<String?> getChangelog(String packageName);
  Future<void> saveChangelogEntry({
    required String packageName,
    required String version,
    required String entry,
    required DateTime date,
  });
  Future<List<Map<String, String>>> getVersionHistory(String packageName);
}

/// Repository interface for roadmap data access.
abstract class IRoadmapRepository {
  Future<List<RoadmapItem>> getRoadmap({RoadmapStatus? status});
  Future<void> saveRoadmapItem(RoadmapItem item);
  Future<void> updateRoadmapItemStatus(String title, RoadmapStatus status);
}
