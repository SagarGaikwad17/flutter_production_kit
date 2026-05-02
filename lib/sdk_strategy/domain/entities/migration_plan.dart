/// Migration plan — represents a migration between package versions.
///
/// Design rationale:
/// - Migrations are version-to-version specific.
/// - Each migration has steps, risk level, and estimated time.
/// - Breaking changes require migration guides.
/// - Non-breaking changes can be auto-migrated.
/// - Migrations are tracked for adoption monitoring.
class MigrationPlan {
  const MigrationPlan({
    required this.packageName,
    required this.fromVersion,
    required this.toVersion,
    required this.isBreaking,
    required this.steps,
    this.riskLevel = MigrationRiskLevel.low,
    this.estimatedTimeMinutes = 30,
    this.migrationGuideUrl,
    this.autoMigrationAvailable = false,
    this.rollbackAvailable = true,
    this.deprecatedApis = const [],
    this.newApis = const [],
    this.renamedApis = const {},
  });

  final String packageName;
  final String fromVersion;
  final String toVersion;
  final bool isBreaking;
  final List<MigrationStep> steps;
  final MigrationRiskLevel riskLevel;
  final int estimatedTimeMinutes;
  final String? migrationGuideUrl;
  final bool autoMigrationAvailable;
  final bool rollbackAvailable;
  final List<String> deprecatedApis;
  final List<String> newApis;
  final Map<String, String> renamedApis;

  bool get requiresManualMigration => !autoMigrationAvailable && isBreaking;
  bool get isSafe => riskLevel == MigrationRiskLevel.low && !isBreaking;
}

enum MigrationRiskLevel {
  low,
  medium,
  high,
  critical,
}

class MigrationStep {
  const MigrationStep({
    required this.order,
    required this.description,
    required this.type,
    this.codeBefore,
    this.codeAfter,
    this.warning,
  });

  final int order;
  final String description;
  final MigrationStepType type;
  final String? codeBefore;
  final String? codeAfter;
  final String? warning;
}

enum MigrationStepType {
  dependencyUpdate,
  apiRename,
  apiRemoval,
  apiAddition,
  behaviorChange,
  configUpdate,
  breakingChange,
  deprecation,
}

/// Migration result — outcome of a migration operation.
sealed class MigrationResult {
  const MigrationResult({required this.packageName});
  final String packageName;

  bool get isSuccess => this is MigrationCompleted;
}

/// Migration completed successfully.
final class MigrationCompleted extends MigrationResult {
  const MigrationCompleted({
    required super.packageName,
    required this.fromVersion,
    required this.toVersion,
    required this.stepsCompleted,
    this.warnings = const [],
  });
  final String fromVersion;
  final String toVersion;
  final int stepsCompleted;
  final List<String> warnings;
}

/// Migration requires manual intervention.
final class MigrationRequiresManualIntervention extends MigrationResult {
  const MigrationRequiresManualIntervention({
    required super.packageName,
    required this.blockingSteps,
    required this.migrationGuideUrl,
  });
  final List<MigrationStep> blockingSteps;
  final String migrationGuideUrl;
}

/// Migration guide required.
final class MigrationGuideRequired extends MigrationResult {
  const MigrationGuideRequired({
    required super.packageName,
    required this.fromVersion,
    required this.toVersion,
    this.guideUrl,
  });
  final String fromVersion;
  final String toVersion;
  final String? guideUrl;
}

/// Upgrade playbook — structured upgrade path for a package.
class UpgradePlaybook {
  const UpgradePlaybook({
    required this.packageName,
    required this.targetVersion,
    required this.preUpgradeChecks,
    required this.upgradeSteps,
    required this.postUpgradeChecks,
    this.rollbackSteps = const [],
    this.estimatedTimeMinutes = 60,
    this.requiresDowntime = false,
  });

  final String packageName;
  final String targetVersion;
  final List<String> preUpgradeChecks;
  final List<String> upgradeSteps;
  final List<String> postUpgradeChecks;
  final List<String> rollbackSteps;
  final int estimatedTimeMinutes;
  final bool requiresDowntime;
}
