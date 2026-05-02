import 'package:flutter_production_kit/sdk_strategy/domain/entities/adoption_metric.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/entities/contribution_record.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/entities/migration_plan.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/entities/package_config.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/entities/version_state.dart';

/// Repository interface for package data access.
abstract class IPackageRepository {
  Future<PackageConfig?> getByName(String packageName);
  Future<List<PackageConfig>> getByCategory(PackageCategory category);
  Future<List<PackageConfig>> getAllPackages();
  Future<void> save(PackageConfig package);
  Future<void> updateStability(String packageName, PackageStability stability);
  Future<void> updateVersion(String packageName, String version);
}

/// Repository interface for version data access.
abstract class IVersionRepository {
  Future<VersionState?> getCurrentVersion(String packageName);
  Future<List<VersionState>> getVersionHistory(String packageName);
  Future<void> recordVersion(VersionState version);
  Future<void> deprecateVersion(String packageName, String version, DateTime endOfLifeDate);
}

/// Repository interface for migration data access.
abstract class IMigrationRepository {
  Future<MigrationPlan?> getMigrationPlan(String packageName, String fromVersion, String toVersion);
  Future<List<MigrationPlan>> getActiveMigrations(String packageName);
  Future<void> saveMigrationPlan(MigrationPlan plan);
  Future<void> recordMigrationOutcome({
    required String packageName,
    required String fromVersion,
    required String toVersion,
    required bool success,
    String? failureReason,
  });
}

/// Repository interface for contribution data access.
abstract class IContributionRepository {
  Future<ContributionRecord?> getById(String contributionId);
  Future<List<ContributionRecord>> getByPackage(String packageName);
  Future<List<ContributionRecord>> getByContributor(String contributorId);
  Future<void> save(ContributionRecord contribution);
  Future<void> updateStatus(String contributionId, ContributionStatus status);
}

/// Repository interface for adoption data access.
abstract class IAdoptionRepository {
  Future<AdoptionMetric?> getLatest(String packageName);
  Future<List<AdoptionMetric>> getHistory(String packageName, {int limit = 30});
  Future<void> record(AdoptionMetric metric);
  Future<Map<String, double>> getAdoptionHeatmap();
}

/// Repository interface for documentation data access.
abstract class IDocumentationRepository {
  Future<Map<String, bool>> getDocumentationStatus(String packageName);
  Future<void> updateDocumentationStatus(String packageName, String docType, bool complete);
  Future<List<String>> getMissingDocumentation(String packageName);
}
