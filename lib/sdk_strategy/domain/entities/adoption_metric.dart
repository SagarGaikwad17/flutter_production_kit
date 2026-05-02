/// Adoption metric — tracks developer adoption of a package.
///
/// Design rationale:
/// - Tracks pub.dev downloads, GitHub stars, and issue health.
/// - Tracks migration success/failure rates.
/// - Tracks contributor quality signals.
/// - Tracks enterprise adoption indicators.
class AdoptionMetric {
  const AdoptionMetric({
    required this.packageName,
    required this.timestamp,
    this.weeklyDownloads,
    this.monthlyDownloads,
    this.githubStars,
    this.forks,
    this.openIssues,
    this.closedIssues,
    this.contributorCount,
    this.pubDevScore,
    this.migrationSuccessRate,
    this.averageIssueResolutionDays,
    this.enterpriseAdopterCount,
  });

  final String packageName;
  final DateTime timestamp;
  final int? weeklyDownloads;
  final int? monthlyDownloads;
  final int? githubStars;
  final int? forks;
  final int? openIssues;
  final int? closedIssues;
  final int? contributorCount;
  final int? pubDevScore;
  final double? migrationSuccessRate;
  final double? averageIssueResolutionDays;
  final int? enterpriseAdopterCount;

  bool get isHealthy {
    final open = openIssues;
    final score = pubDevScore;
    final rate = migrationSuccessRate;
    if (open != null && open > 100) return false;
    if (score != null && score < 80) return false;
    if (rate != null && rate < 0.90) return false;
    return true;
  }

  bool get isGrowing {
    final weekly = weeklyDownloads;
    final monthly = monthlyDownloads;
    if (weekly == null || monthly == null) return false;
    final weeklyAvg = monthly / 4.3;
    return weekly > weeklyAvg;
  }
}

/// Trust score — represents the trustworthiness of a package for enterprise adoption.
class TrustScore {
  const TrustScore({
    required this.packageName,
    required this.overallScore,
    required this.documentationScore,
    required this.stabilityScore,
    required this.securityScore,
    required this.maintainerScore,
    required this.communityScore,
    this.enterpriseReady = false,
    this.certifications = const [],
    this.lastAuditDate,
  });

  final String packageName;
  final double overallScore;
  final double documentationScore;
  final double stabilityScore;
  final double securityScore;
  final double maintainerScore;
  final double communityScore;
  final bool enterpriseReady;
  final List<String> certifications;
  final DateTime? lastAuditDate;

  bool get isProductionReady => overallScore >= 0.90 && enterpriseReady;
  bool get needsImprovement => overallScore < 0.70;
}

/// Readiness result — outcome of a readiness assessment.
sealed class ReadinessResult {
  const ReadinessResult({required this.packageName});
  final String packageName;

  bool get isReady => this is PubDevReadinessApproved || this is EnterpriseReadinessCertified;
}

/// Package is pub.dev ready.
final class PubDevReadinessApproved extends ReadinessResult {
  const PubDevReadinessApproved({
    required super.packageName,
    required this.score,
    this.checks = const [],
  });
  final int score;
  final List<String> checks;
}

/// Package is enterprise readiness certified.
final class EnterpriseReadinessCertified extends ReadinessResult {
  const EnterpriseReadinessCertified({
    required super.packageName,
    required this.trustScore,
    this.certifications = const [],
    this.auditReportUrl,
  });
  final TrustScore trustScore;
  final List<String> certifications;
  final String? auditReportUrl;
}

/// Package not ready for pub.dev.
final class PackageNotReadyForPubDev extends ReadinessResult {
  const PackageNotReadyForPubDev({
    required super.packageName,
    required this.blockingIssues,
    this.recommendedActions = const [],
  });
  final List<String> blockingIssues;
  final List<String> recommendedActions;
}

/// Package fails enterprise readiness.
final class EnterpriseReadinessFailed extends ReadinessResult {
  const EnterpriseReadinessFailed({
    required super.packageName,
    required this.failedChecks,
    this.recommendedActions = const [],
  });
  final List<String> failedChecks;
  final List<String> recommendedActions;
}
