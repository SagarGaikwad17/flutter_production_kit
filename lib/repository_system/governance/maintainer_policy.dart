import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';

/// Maintainer policy — defines maintainer responsibilities and boundaries.
///
/// Design rationale:
/// - Maintainer workload must be sustainable.
/// - Clear policies prevent burnout and ensure consistent project health.
/// - Decision framework provides objective criteria for PR/issue decisions.
///
/// Policy areas:
/// 1. Response time expectations (issues, PRs, questions).
/// 2. Review standards (minimum reviews, approval criteria).
/// 3. Release cadence (regular, hotfix, security).
/// 4. Breaking change policy (deprecation windows, migration guides).
/// 5. Contribution guidelines (welcome, review, merge).
/// 6. Escalation paths (when to defer, when to reject).
class MaintainerPolicy {
  const MaintainerPolicy({
    this.issueResponseTime = const Duration(hours: 48),
    this.prResponseTime = const Duration(hours: 24),
    this.minimumReviewers = 2,
    this.releaseCadence = const Duration(days: 14),
    this.hotfixCadence = const Duration(days: 1),
    this.deprecationWindowMonths = 6,
    this.maxOpenIssuesBeforeAlert = 50,
    this.maxOpenPRsBeforeAlert = 20,
    this.maintainerMaxConcurrentPRs = 5,
    this.autoCloseStaleAfter = const Duration(days: 90),
    this.staleWarningAfter = const Duration(days: 60),
  });

  final Duration issueResponseTime;
  final Duration prResponseTime;
  final int minimumReviewers;
  final Duration releaseCadence;
  final Duration hotfixCadence;
  final int deprecationWindowMonths;
  final int maxOpenIssuesBeforeAlert;
  final int maxOpenPRsBeforeAlert;
  final int maintainerMaxConcurrentPRs;
  final Duration autoCloseStaleAfter;
  final Duration staleWarningAfter;

  /// Check if maintainer workload is sustainable.
  RepoResult checkWorkloadSustainability({
    required int openIssues,
    required int openPRs,
    required int activeMaintainers,
    required List<String> recentActivity,
  }) {
    final indicators = <String>[];
    final recommendations = <String>[];
    var riskLevel = 'low';

    // Check issue load
    if (openIssues > maxOpenIssuesBeforeAlert) {
      indicators.add('$openIssues open issues (threshold: $maxOpenIssuesBeforeAlert)');
      recommendations.add('Triage and close stale issues');
      recommendations.add('Add "good-first-issue" labels for community help');
      riskLevel = 'high';
    }

    // Check PR load
    if (openPRs > maxOpenPRsBeforeAlert) {
      indicators.add('$openPRs open PRs (threshold: $maxOpenPRsBeforeAlert)');
      recommendations.add('Prioritize older PRs for review');
      recommendations.add('Request more maintainers for review');
      riskLevel = 'high';
    }

    // Check maintainer capacity
    final prsPerMaintainer = openPRs / activeMaintainers;
    if (prsPerMaintainer > maintainerMaxConcurrentPRs) {
      indicators.add(
        '${prsPerMaintainer.toStringAsFixed(1)} PRs per maintainer '
        '(threshold: $maintainerMaxConcurrentPRs)',
      );
      recommendations.add('Recruit additional maintainers');
      riskLevel = 'critical';
    }

    // Check recent activity
    if (recentActivity.isEmpty) {
      indicators.add('No recent maintainer activity');
      recommendations.add('Schedule regular maintenance windows');
      riskLevel = riskLevel == 'low' ? 'medium' : riskLevel;
    }

    if (indicators.isNotEmpty) {
      return MaintainerOverloadRiskDetected(
        operation: 'check_workload_sustainability',
        riskLevel: riskLevel,
        indicators: indicators,
        recommendations: recommendations,
      );
    }

    return RepositoryLaunchValidated(
      operation: 'check_workload_sustainability',
      checks: ['Workload is sustainable'],
    );
  }

  /// Determine if an issue should be auto-closed as stale.
  bool shouldAutoClose({
    required DateTime lastActivity,
    required bool hasAssignee,
    required bool isLabeled,
  }) {
    final now = DateTime.now();
    final inactive = now.difference(lastActivity);

    if (inactive > autoCloseStaleAfter && !hasAssignee && !isLabeled) {
      return true;
    }

    return false;
  }

  /// Determine if a stale warning should be issued.
  bool shouldWarnStale({
    required DateTime lastActivity,
    required bool hasAssignee,
  }) {
    final now = DateTime.now();
    final inactive = now.difference(lastActivity);

    if (inactive > staleWarningAfter && !hasAssignee) {
      return true;
    }

    return false;
  }

  /// Calculate expected response time for an issue/PR.
  Duration expectedResponseTime({required bool isPR}) {
    return isPR ? prResponseTime : issueResponseTime;
  }
}

/// Decision framework — provides objective criteria for maintainer decisions.
///
/// Design rationale:
/// - Decisions should be based on objective criteria, not personal preference.
/// - Framework provides scoring for PR acceptance, feature adoption, and priority.
/// - Reduces maintainer decision fatigue.
///
/// Decision types:
/// 1. PR acceptance (score-based, with veto conditions).
/// 2. Feature adoption (impact vs effort matrix).
/// 3. Issue priority (severity × impact × urgency).
/// 4. Breaking change approval (risk assessment).
/// 5. Deprecation timeline (usage-based).
class DecisionFramework {
  const DecisionFramework({
    this.prAcceptanceThreshold = 70,
    this.featureAdoptionThreshold = 60,
    this.breakingChangeRiskThreshold = 30,
    this.priorityWeights = const {
      'severity': 0.4,
      'impact': 0.35,
      'urgency': 0.25,
    },
  });

  final int prAcceptanceThreshold;
  final int featureAdoptionThreshold;
  final int breakingChangeRiskThreshold;
  final Map<String, double> priorityWeights;

  /// Score a PR for acceptance.
  int scorePR({
    required bool testsPass,
    required bool lintPass,
    required bool formatPass,
    required int reviewerApprovals,
    required int minimumReviewers,
    required bool changelogUpdated,
    required bool documentationUpdated,
    required bool architectureCompliant,
    required bool noBreakingChanges,
    required int codeQuality,
  }) {
    int score = 0;

    // Tests (20 points)
    if (testsPass) {
      score += 20;
    }

    // Lint + Format (10 points)
    if (lintPass) {
      score += 5;
    }
    if (formatPass) {
      score += 5;
    }

    // Reviews (25 points)
    final reviewRatio = reviewerApprovals / minimumReviewers;
    score += (reviewRatio * 25).round().clamp(0, 25);

    // Changelog (5 points)
    if (changelogUpdated) {
      score += 5;
    }

    // Documentation (5 points)
    if (documentationUpdated) {
      score += 5;
    }

    // Architecture (15 points)
    if (architectureCompliant) {
      score += 15;
    }

    // Breaking changes (10 points)
    if (noBreakingChanges) {
      score += 10;
    }

    // Code quality (5 points)
    score += codeQuality.clamp(0, 5);

    return score;
  }

  /// Determine if a PR should be accepted.
  bool shouldAcceptPR({
    required int score,
    required bool hasVeto,
    required bool isHotfix,
  }) {
    if (hasVeto) return false;
    if (isHotfix) return score >= (prAcceptanceThreshold - 20);
    return score >= prAcceptanceThreshold;
  }

  /// Score a feature request for adoption.
  int scoreFeature({
    required int userDemand,
    required int implementationEffort,
    required bool alignsWithRoadmap,
    required bool isRequestedByEnterprise,
    required bool hasCommunitySupport,
  }) {
    int score = 0;

    // User demand (0-30 points)
    score += userDemand.clamp(0, 30);

    // Implementation effort (0-20 points, inverted — lower effort = higher score)
    score += (100 - implementationEffort).clamp(0, 20) ~/ 5;

    // Roadmap alignment (20 points)
    if (alignsWithRoadmap) score += 20;

    // Enterprise request (15 points)
    if (isRequestedByEnterprise) score += 15;

    // Community support (15 points)
    if (hasCommunitySupport) score += 15;

    return score;
  }

  /// Calculate issue priority score.
  double calculateIssuePriority({
    required double severity,   // 0-100
    required double impact,     // 0-100
    required double urgency,    // 0-100
  }) {
    return (severity * priorityWeights['severity']!) +
        (impact * priorityWeights['impact']!) +
        (urgency * priorityWeights['urgency']!);
  }

  /// Assess breaking change risk.
  int assessBreakingChangeRisk({
    required int affectedUsers,
    required bool hasMigrationGuide,
    required int deprecationNoticeDays,
    required bool isReversible,
  }) {
    int risk = 0;

    // User impact (0-40 points)
    if (affectedUsers > 1000) {
      risk += 40;
    } else if (affectedUsers > 100) {
      risk += 30;
    } else if (affectedUsers > 10) {
      risk += 20;
    } else {
      risk += 10;
    }

    // Migration guide (0-25 points, inverted)
    if (!hasMigrationGuide) {
      risk += 25;
    }

    // Deprecation notice (0-20 points, inverted)
    if (deprecationNoticeDays < 30) {
      risk += 20;
    } else if (deprecationNoticeDays < 90) {
      risk += 10;
    }

    // Reversibility (0-15 points, inverted)
    if (!isReversible) {
      risk += 15;
    }

    return risk;
  }

  /// Determine if breaking change is acceptable.
  bool isBreakingChangeAcceptable({
    required int riskScore,
    required bool hasMigrationGuide,
    required bool hasApproval,
  }) {
    if (riskScore > breakingChangeRiskThreshold) return false;
    if (!hasMigrationGuide) return false;
    if (!hasApproval) return false;
    return true;
  }
}
