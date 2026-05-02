import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Maintainer sustainability engine — prevents burnout and ensures project longevity.
///
/// Design rationale:
/// - Maintainer burnout is the #1 cause of open-source project failure.
/// - Early detection of overload indicators enables intervention.
/// - Automated task distribution reduces maintainer burden.
/// - Sustainable cadence prevents feast-or-famine cycles.
///
/// Sustainability indicators:
/// 1. Workload distribution (issues, PRs, reviews per maintainer).
/// 2. Response time trends (increasing times signal overload).
/// 3. Issue/PR backlog growth (growing backlog = unsustainable).
/// 4. Maintainer activity patterns (long gaps, weekend-only work).
/// 5. Community self-sufficiency (can community handle tasks without maintainers?).
/// 6. Financial sustainability (sponsors, grants, paid support).
class MaintainerSustainabilityEngine {
  const MaintainerSustainabilityEngine({
    required IContributorRepository contributorRepository,
    this.maxHoursPerWeek = 20,
    this.burnoutIndicators = const {
      'weekend_only_activity': 'Working only on weekends',
      'increasing_response_times': 'Response times increasing over 4 weeks',
      'growing_backlog': 'Backlog growing faster than resolution rate',
      'no_time_off': 'No time off in last 30 days',
      'high_pr_volume': 'Handling more than 10 PRs per week',
      'single_maintainer_bottleneck': 'One maintainer handling >50% of workload',
    },
    this.automationRules = const {
      'auto_triage': true,
      'auto_label': true,
      'auto_close_stale': true,
      'auto_assign_reviewers': true,
    },
  }) : _contributorRepository = contributorRepository;

  final IContributorRepository _contributorRepository;
  final int maxHoursPerWeek;
  final Map<String, String> burnoutIndicators;
  final Map<String, bool> automationRules;

  /// Assess maintainer sustainability.
  Future<RepoResult> assessSustainability({
    required String maintainerId,
    required int hoursPerWeek,
    required int openPRs,
    required int openIssues,
    required Duration avgResponseTime,
    required List<DateTime> activityDates,
    required double communitySelfSufficiency,
  }) async {
    final indicators = <String>[];
    final recommendations = <String>[];
    var riskLevel = 'low';

    // Check hours per week
    if (hoursPerWeek > maxHoursPerWeek) {
      indicators.add(
        'Working $hoursPerWeek hours/week (max: $maxHoursPerWeek)',
      );
      recommendations.add('Reduce scope or recruit more maintainers');
      riskLevel = 'high';
    }

    // Check response time trends
    if (avgResponseTime > const Duration(hours: 48)) {
      indicators.add(
        'Average response time: ${avgResponseTime.inHours}h (healthy: <48h)',
      );
      recommendations.add('Enable auto-triage for faster routing');
      recommendations.add('Set expectations for response times in README');
      riskLevel = riskLevel == 'low' ? 'medium' : riskLevel;
    }

    // Check backlog growth
    final totalWork = openPRs + openIssues;
    if (totalWork > 50) {
      indicators.add('Total open work: $totalWork (healthy: <50)');
      recommendations.add('Prioritize and close stale items');
      recommendations.add('Add "help-wanted" labels for community');
      riskLevel = 'high';
    }

    // Check activity patterns
    final weekendOnly = _isWeekendOnlyActivity(activityDates);
    if (weekendOnly) {
      indicators.add(burnoutIndicators['weekend_only_activity']!);
      recommendations.add('Schedule dedicated weekday maintenance time');
      riskLevel = riskLevel == 'low' ? 'medium' : riskLevel;
    }

    // Check time off
    final noTimeOff = _hasNoTimeOff(activityDates);
    if (noTimeOff) {
      indicators.add(burnoutIndicators['no_time_off']!);
      recommendations.add('Take at least one day off this week');
      riskLevel = 'high';
    }

    // Check PR volume
    if (openPRs > 10) {
      indicators.add(burnoutIndicators['high_pr_volume']!);
      recommendations.add('Delegate PR reviews to trusted contributors');
      recommendations.add('Enable auto-merge for trusted contributors');
      riskLevel = 'high';
    }

    // Check community self-sufficiency
    if (communitySelfSufficiency < 0.3) {
      indicators.add(
        'Community self-sufficiency: ${(communitySelfSufficiency * 100).round()}% (healthy: >30%)',
      );
      recommendations.add('Invest in community mentorship');
      recommendations.add('Document common tasks for self-service');
      riskLevel = riskLevel == 'low' ? 'medium' : riskLevel;
    }

    if (indicators.isNotEmpty) {
      throw MaintainerOverloadException(
        message: 'Maintainer sustainability risk detected',
        currentLoad: hoursPerWeek,
        maxCapacity: maxHoursPerWeek,
      );
    }

    return RepositoryLaunchValidated(
      operation: 'assess_sustainability',
      checks: ['Sustainability is healthy'],
    );
  }

  /// Generate automation recommendations to reduce maintainer load.
  List<String> generateAutomationRecommendations({
    required int openPRs,
    required int openIssues,
    required Duration avgResponseTime,
  }) {
    final recommendations = <String>[];

    if (openIssues > 20 && automationRules['auto_triage'] == true) {
      recommendations.add(
        'Enable auto-triage to classify and route issues automatically',
      );
    }

    if (openIssues > 30 && automationRules['auto_label'] == true) {
      recommendations.add(
        'Enable auto-labeling to reduce manual triage effort',
      );
    }

    if (openIssues > 40 && automationRules['auto_close_stale'] == true) {
      recommendations.add(
        'Enable auto-close for stale issues (90+ days inactive)',
      );
    }

    if (openPRs > 5 && automationRules['auto_assign_reviewers'] == true) {
      recommendations.add(
        'Enable auto-assign reviewers to distribute review load',
      );
    }

    return recommendations;
  }

  /// Calculate community self-sufficiency score.
  double calculateCommunitySelfSufficiency({
    required int communityPRs,
    required int maintainerPRs,
    required int communityReviews,
    required int maintainerReviews,
    required int communityIssueResponses,
    required int maintainerIssueResponses,
  }) {
    final totalPRs = communityPRs + maintainerPRs;
    final totalReviews = communityReviews + maintainerReviews;
    final totalResponses = communityIssueResponses + maintainerIssueResponses;

    if (totalPRs + totalReviews + totalResponses == 0) return 0.0;

    final communityContribution =
        (communityPRs + communityReviews + communityIssueResponses) /
        (totalPRs + totalReviews + totalResponses);

    return communityContribution.clamp(0.0, 1.0);
  }

  /// Generate a sustainability report.
  Future<Map<String, dynamic>> generateSustainabilityReport({
    required List<String> maintainerIds,
    required Map<String, int> hoursPerWeek,
    required Map<String, int> openPRs,
    required Map<String, int> openIssues,
  }) async {
    final report = <String, dynamic>{};

    for (final id in maintainerIds) {
      final contributor = await _contributorRepository.getContributor(id);
      if (contributor == null) continue;

      report[id] = {
        'status': contributor.status.name,
        'reputation': contributor.reputationScore,
        'hours_per_week': hoursPerWeek[id] ?? 0,
        'open_prs': openPRs[id] ?? 0,
        'open_issues': openIssues[id] ?? 0,
        'is_trusted': contributor.isTrusted,
        'is_active': contributor.isActive,
      };
    }

    return report;
  }

  bool _isWeekendOnlyActivity(List<DateTime> activityDates) {
    if (activityDates.isEmpty) return false;

    final weekendDays = activityDates
        .where((d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday)
        .length;

    return weekendDays / activityDates.length > 0.8;
  }

  bool _hasNoTimeOff(List<DateTime> activityDates) {
    if (activityDates.isEmpty) return false;

    final now = DateTime.now();
    final last30Days = activityDates
        .where((d) => now.difference(d).inDays <= 30)
        .toList();

    // Check for gaps of 2+ consecutive days
    last30Days.sort();
    for (var i = 1; i < last30Days.length; i++) {
      final gap = last30Days[i].difference(last30Days[i - 1]).inDays;
      if (gap >= 2) return false;
    }

    return true;
  }
}
