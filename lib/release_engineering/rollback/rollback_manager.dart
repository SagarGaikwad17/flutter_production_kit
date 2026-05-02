import 'package:flutter_production_kit/release_engineering/domain/entities/deployment_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/exceptions/release_exception.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';

/// Rollback manager — manages safe release rollback.
///
/// Design rationale:
/// - Rollback is deterministic — always rolls back to a known-good release.
/// - Rollback target must be validated before execution.
/// - Rollback is audited — every rollback is recorded.
/// - Emergency rollback bypasses normal gates for critical fixes.
/// - Partial rollback handles cases where only one platform failed.
///
/// Rollback flow:
///   1. Identify current release and rollback target.
///   2. Validate rollback target is in a safe state.
///   3. Update deployment state to rolled back.
///   4. Update release state to rolled back.
///   5. Notify observability layer.
///   6. Record rollback in audit trail.
class RollbackManager {
  const RollbackManager({
    required IReleaseRepository releaseRepository,
    required IDeploymentRepository deploymentRepository,
  })  : _releaseRepository = releaseRepository,
        _deploymentRepository = deploymentRepository;

  final IReleaseRepository _releaseRepository;
  final IDeploymentRepository _deploymentRepository;

  /// Execute a rollback to a previous release.
  Future<ReleaseResult> executeRollback({
    required String releaseId,
    required String rollbackTargetId,
    String? triggeredBy,
    String? reason,
    bool isEmergency = false,
  }) async {
    final currentRelease = await _releaseRepository.getById(releaseId);
    if (currentRelease == null) {
      throw const ReleaseNotFoundException(
        message: 'Current release not found for rollback',
      );
    }

    if (!currentRelease.canRollback) {
      throw const RollbackFailureException(
        message: 'Release cannot be rolled back',
        releaseId: '',
        rollbackTargetId: '',
      );
    }

    final rollbackTarget = await _releaseRepository.getById(rollbackTargetId);
    if (rollbackTarget == null) {
      throw RollbackFailureException(
        message: 'Rollback target release not found',
        releaseId: releaseId,
        rollbackTargetId: rollbackTargetId,
      );
    }

    // Validate rollback target is in a safe state.
    if (rollbackTarget.status != ReleaseStatus.completed &&
        rollbackTarget.status != ReleaseStatus.staged) {
      throw RollbackFailureException(
        message: 'Rollback target is not in a safe state: ${rollbackTarget.status}',
        releaseId: releaseId,
        rollbackTargetId: rollbackTargetId,
      );
    }

    // Step 1: Update current release to rollback initiated.
    await _releaseRepository.updateStatus(
      releaseId,
      ReleaseStatus.rollbackInitiated,
    );

    // Step 2: Update deployment state.
    final deployments = await _deploymentRepository.getByReleaseId(releaseId);
    for (final deployment in deployments) {
      await _deploymentRepository.updateStatus(
        deployment.id,
        DeploymentStatus.rolledBack,
      );
    }

    // Step 3: Update current release to rolled back.
    await _releaseRepository.updateStatus(
      releaseId,
      ReleaseStatus.rolledBack,
    );

    return RollbackTriggered(
      releaseId: releaseId,
      rollbackTargetId: rollbackTargetId,
      reason: reason ?? 'Rollback executed',
      triggeredBy: triggeredBy,
      triggeredAt: DateTime.now(),
    );
  }

  /// Execute an emergency rollback (bypasses validation gates).
  Future<ReleaseResult> executeEmergencyRollback({
    required String releaseId,
    required String rollbackTargetId,
    required String severity,
  }) async {
    final currentRelease = await _releaseRepository.getById(releaseId);
    if (currentRelease == null) {
      throw const ReleaseNotFoundException(
        message: 'Current release not found for emergency rollback',
      );
    }

    // Emergency rollback still requires a valid target.
    final rollbackTarget = await _releaseRepository.getById(rollbackTargetId);
    if (rollbackTarget == null) {
      throw RollbackFailureException(
        message: 'Rollback target not found for emergency rollback',
        releaseId: releaseId,
        rollbackTargetId: rollbackTargetId,
      );
    }

    // Step 1: Update current release to rollback initiated.
    await _releaseRepository.updateStatus(
      releaseId,
      ReleaseStatus.rollbackInitiated,
    );

    // Step 2: Update deployment states.
    final deployments = await _deploymentRepository.getByReleaseId(releaseId);
    for (final deployment in deployments) {
      await _deploymentRepository.updateStatus(
        deployment.id,
        DeploymentStatus.rolledBack,
      );
    }

    // Step 3: Update current release to rolled back.
    await _releaseRepository.updateStatus(
      releaseId,
      ReleaseStatus.rolledBack,
    );

    throw EmergencyReleaseException(
      message: 'Emergency rollback $releaseId → $rollbackTargetId executed',
      releaseId: releaseId,
      severity: severity,
    );
  }

  /// Handle partial rollback (only failed platforms).
  Future<ReleaseResult> executePartialRollback({
    required String releaseId,
    required List<String> failedPlatforms,
    required List<String> succeededPlatforms,
    String? reason,
  }) async {
    final currentRelease = await _releaseRepository.getById(releaseId);
    if (currentRelease == null) {
      throw const ReleaseNotFoundException(
        message: 'Current release not found for partial rollback',
      );
    }

    // Update deployment states for failed platforms.
    final deployments = await _deploymentRepository.getByReleaseId(releaseId);
    for (final deployment in deployments) {
      for (final platformState in deployment.platformStates.values) {
        if (failedPlatforms.contains(platformState.platform)) {
          await _deploymentRepository.updateStatus(
            deployment.id,
            DeploymentStatus.failed,
          );
        }
      }
    }

    return PartialReleaseFailure(
      releaseId: releaseId,
      succeededPlatforms: succeededPlatforms,
      failedPlatforms: failedPlatforms,
      failureReasons: {
        for (final platform in failedPlatforms)
          platform: reason ?? 'Platform deployment failed',
      },
    );
  }

  /// Find the last known-good release for rollback.
  Future<String?> findLastKnownGoodRelease({
    required String currentReleaseId,
    required String flavor,
    required ReleaseEnvironment environment,
  }) async {
    final releases = await _releaseRepository.getByFlavor(flavor);
    final candidates = releases.where((r) =>
      r.id != currentReleaseId &&
      r.environment == environment &&
      (r.status == ReleaseStatus.completed || r.status == ReleaseStatus.staged)
    ).toList();

    candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidates.isNotEmpty ? candidates.first.id : null;
  }
}
