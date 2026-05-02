import 'package:flutter_production_kit/sdk_strategy/domain/entities/migration_plan.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/exceptions/sdk_exception.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/repositories/sdk_repositories.dart';

/// Migration engine — manages version-to-version migration paths.
///
/// Design rationale:
/// - Migrations are structured as ordered steps.
/// - Each step has code examples (before/after).
/// - Breaking changes require manual migration.
/// - Non-breaking changes can be auto-migrated.
/// - Migration outcomes are tracked for adoption monitoring.
///
/// Migration flow:
///   1. Identify current and target versions.
///   2. Load migration plan.
///   3. Execute steps in order.
///   4. Validate migration success.
///   5. Record migration outcome.
class MigrationEngine {
  const MigrationEngine({
    required IMigrationRepository migrationRepository,
  }) : _migrationRepository = migrationRepository;

  final IMigrationRepository _migrationRepository;

  /// Get migration plan for a version upgrade.
  Future<MigrationPlan?> getMigrationPlan({
    required String packageName,
    required String fromVersion,
    required String toVersion,
  }) async {
    return _migrationRepository.getMigrationPlan(
      packageName,
      fromVersion,
      toVersion,
    );
  }

  /// Execute migration steps.
  Future<MigrationResult> executeMigration({
    required String packageName,
    required String fromVersion,
    required String toVersion,
    required List<MigrationStep> steps,
  }) async {
    final failedSteps = <MigrationStep>[];
    var completedCount = 0;

    for (final step in steps) {
      final success = await _executeStep(step);
      if (!success) {
        failedSteps.add(step);
      } else {
        completedCount++;
      }
    }

    if (failedSteps.isEmpty) {
      await _migrationRepository.recordMigrationOutcome(
        packageName: packageName,
        fromVersion: fromVersion,
        toVersion: toVersion,
        success: true,
      );

      return MigrationCompleted(
        packageName: packageName,
        fromVersion: fromVersion,
        toVersion: toVersion,
        stepsCompleted: completedCount,
      );
    }

    await _migrationRepository.recordMigrationOutcome(
      packageName: packageName,
      fromVersion: fromVersion,
      toVersion: toVersion,
      success: false,
      failureReason: '${failedSteps.length} steps failed',
    );

    throw MigrationFailureException(
      message: 'Migration failed: ${failedSteps.length} steps failed',
      packageName: packageName,
      fromVersion: fromVersion,
      toVersion: toVersion,
      failedSteps: failedSteps.map((s) => s.description).toList(),
    );
  }

  /// Check if migration guide is required for an upgrade.
  Future<MigrationResult> checkMigrationGuideRequired({
    required String packageName,
    required String fromVersion,
    required String toVersion,
    required bool isBreaking,
  }) async {
    if (!isBreaking) {
      return MigrationCompleted(
        packageName: packageName,
        fromVersion: fromVersion,
        toVersion: toVersion,
        stepsCompleted: 0,
      );
    }

    final plan = await getMigrationPlan(
      packageName: packageName,
      fromVersion: fromVersion,
      toVersion: toVersion,
    );

    if (plan == null) {
      return MigrationGuideRequired(
        packageName: packageName,
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }

    if (plan.requiresManualMigration) {
      return MigrationRequiresManualIntervention(
        packageName: packageName,
        blockingSteps: plan.steps,
        migrationGuideUrl: plan.migrationGuideUrl ?? '',
      );
    }

    return MigrationCompleted(
      packageName: packageName,
      fromVersion: fromVersion,
      toVersion: toVersion,
      stepsCompleted: plan.steps.length,
    );
  }

  Future<bool> _executeStep(MigrationStep step) async {
    // In production, this would execute the actual migration step.
    // For now, return success.
    return true;
  }
}

/// Upgrade playbook manager — manages structured upgrade paths.
class UpgradePlaybookManager {
  const UpgradePlaybookManager({
    this.defaultPreUpgradeChecks = const [
      'Backup current configuration',
      'Verify current version compatibility',
      'Check dependency conflicts',
      'Review migration guide',
      'Ensure test coverage',
    ],
    this.defaultPostUpgradeChecks = const [
      'Run full test suite',
      'Verify API compatibility',
      'Check feature flags',
      'Monitor error rates',
      'Validate user flows',
    ],
  });

  final List<String> defaultPreUpgradeChecks;
  final List<String> defaultPostUpgradeChecks;

  /// Generate an upgrade playbook for a package.
  UpgradePlaybook generatePlaybook({
    required String packageName,
    required String targetVersion,
    List<String>? preUpgradeChecks,
    List<String>? upgradeSteps,
    List<String>? postUpgradeChecks,
    List<String>? rollbackSteps,
    int? estimatedTimeMinutes,
    bool? requiresDowntime,
  }) {
    return UpgradePlaybook(
      packageName: packageName,
      targetVersion: targetVersion,
      preUpgradeChecks: preUpgradeChecks ?? defaultPreUpgradeChecks,
      upgradeSteps: upgradeSteps ?? [
        'Update dependency to $targetVersion',
        'Run migration script',
        'Update configuration',
        'Run tests',
      ],
      postUpgradeChecks: postUpgradeChecks ?? defaultPostUpgradeChecks,
      rollbackSteps: rollbackSteps ?? [
        'Revert dependency to previous version',
        'Restore configuration backup',
        'Run tests',
      ],
      estimatedTimeMinutes: estimatedTimeMinutes ?? 60,
      requiresDowntime: requiresDowntime ?? false,
    );
  }
}
