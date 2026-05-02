import 'package:flutter_production_kit/sdk_strategy/domain/entities/adoption_metric.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/repositories/sdk_repositories.dart';

/// Developer adoption engine — tracks and optimizes SDK adoption.
///
/// Design rationale:
/// - Tracks adoption metrics per package.
/// - Identifies adoption bottlenecks.
/// - Tracks migration success rates.
/// - Tracks issue resolution health.
/// - Tracks contributor quality signals.
///
/// Adoption signals:
/// - Weekly/monthly downloads (pub.dev).
/// - GitHub stars and forks.
/// - Issue open/close ratio.
/// - Average issue resolution time.
/// - Contributor count and activity.
/// - Migration success rate.
/// - Enterprise adopter count.
class DeveloperAdoptionEngine {
  const DeveloperAdoptionEngine({
    required IAdoptionRepository adoptionRepository,
    this.healthyDownloadGrowthRate = 0.10,
    this.healthyIssueResolutionDays = 7.0,
    this.healthyMigrationSuccessRate = 0.90,
    this.healthyPubDevScore = 100,
  }) : _adoptionRepository = adoptionRepository;

  final IAdoptionRepository _adoptionRepository;
  final double healthyDownloadGrowthRate;
  final double healthyIssueResolutionDays;
  final double healthyMigrationSuccessRate;
  final int healthyPubDevScore;

  /// Get latest adoption metrics for a package.
  Future<AdoptionMetric?> getLatestMetrics(String packageName) async {
    return _adoptionRepository.getLatest(packageName);
  }

  /// Get adoption history for a package.
  Future<List<AdoptionMetric>> getAdoptionHistory(
    String packageName, {
    int limit = 30,
  }) async {
    return _adoptionRepository.getHistory(packageName, limit: limit);
  }

  /// Check if a package's adoption is healthy.
  Future<AdoptionHealth> checkAdoptionHealth(String packageName) async {
    final metrics = await _adoptionRepository.getLatest(packageName);
    if (metrics == null) {
      return const AdoptionHealth(
        packageName: '',
        isHealthy: false,
        signals: ['No adoption data available'],
      );
    }

    final signals = <String>[];
    var isHealthy = true;

    if (metrics.weeklyDownloads != null && metrics.monthlyDownloads != null) {
      final weeklyAvg = metrics.monthlyDownloads! / 4.3;
      final growthRate = (metrics.weeklyDownloads! - weeklyAvg) / weeklyAvg;
      if (growthRate < healthyDownloadGrowthRate) {
        isHealthy = false;
        signals.add('Download growth rate below threshold');
      }
    }

    if (metrics.openIssues != null && metrics.openIssues! > 100) {
      isHealthy = false;
      signals.add('Too many open issues (${metrics.openIssues})');
    }

    if (metrics.averageIssueResolutionDays != null &&
        metrics.averageIssueResolutionDays! > healthyIssueResolutionDays) {
      isHealthy = false;
      signals.add('Issue resolution time above threshold');
    }

    if (metrics.migrationSuccessRate != null &&
        metrics.migrationSuccessRate! < healthyMigrationSuccessRate) {
      isHealthy = false;
      signals.add('Migration success rate below threshold');
    }

    if (metrics.pubDevScore != null &&
        metrics.pubDevScore! < healthyPubDevScore) {
      isHealthy = false;
      signals.add('Pub.dev score below threshold');
    }

    return AdoptionHealth(
      packageName: packageName,
      isHealthy: isHealthy,
      signals: signals.isEmpty ? ['All adoption signals healthy'] : signals,
    );
  }

  /// Get adoption heatmap across all packages.
  Future<Map<String, double>> getAdoptionHeatmap() async {
    return _adoptionRepository.getAdoptionHeatmap();
  }
}

/// Adoption health — represents the health of a package's adoption.
class AdoptionHealth {
  const AdoptionHealth({
    required this.packageName,
    required this.isHealthy,
    this.signals = const [],
  });

  final String packageName;
  final bool isHealthy;
  final List<String> signals;
}
