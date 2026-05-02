import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/rollout_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/exceptions/release_exception.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';

/// Staged rollout engine — manages incremental release deployment.
///
/// Design rationale:
/// - Rollout percentage increases in controlled increments.
/// - Health gates monitor rollout safety at each step.
/// - Region-based rollout allows geographic staging.
/// - Tenant-based rollout allows enterprise customer staging.
/// - Emergency rollback bypasses normal gates for critical fixes.
///
/// Rollout strategy:
///   1. Initial deployment to 1% of users.
///   2. Monitor health gates for 15 minutes.
///   3. If healthy, increase to 10%.
///   4. Monitor for 30 minutes.
///   5. If healthy, increase to 25%, then 50%, then 100%.
///   6. If any gate triggers, pause rollout.
///   7. If critical gate triggers, initiate rollback.
///
/// Health gates:
/// - Crash rate: pause at 2x baseline, rollback at 5x baseline.
/// - API error rate: pause at 3x baseline, rollback at 10x baseline.
/// - User complaints: pause at threshold, rollback at 2x threshold.
/// - Billing failures: pause at 2x baseline, rollback at 5x baseline.
/// - Tenant isolation violations: immediate rollback.
class StagedRolloutEngine {
  const StagedRolloutEngine({
    required IRolloutRepository rolloutRepository,
    this.rolloutIncrements = const [1, 10, 25, 50, 100],
    this.defaultHealthGates = const {
      'crash_rate': RolloutHealthGate(
        name: 'crash_rate',
        threshold: 0.02,
        metric: 'crashes_per_1000_sessions',
        rollbackThreshold: 0.05,
      ),
      'api_error_rate': RolloutHealthGate(
        name: 'api_error_rate',
        threshold: 0.03,
        metric: 'errors_per_1000_requests',
        rollbackThreshold: 0.10,
      ),
      'tenant_isolation': RolloutHealthGate(
        name: 'tenant_isolation',
        threshold: 0.0,
        metric: 'isolation_violations',
        rollbackThreshold: 0.0,
      ),
    },
  }) : _rolloutRepository = rolloutRepository;

  final IRolloutRepository _rolloutRepository;
  final List<int> rolloutIncrements;
  final Map<String, RolloutHealthGate> defaultHealthGates;

  /// Start a staged rollout.
  Future<RolloutState> startRollout({
    required String releaseId,
    int targetPercentage = 100,
    List<String> regions = const [],
    List<String> tenantIds = const [],
    Map<String, RolloutHealthGate>? healthGates,
  }) async {
    final state = RolloutState(
      id: _generateRolloutId(),
      releaseId: releaseId,
      currentPercentage: 0,
      targetPercentage: targetPercentage,
      status: RolloutStatus.active,
      startedAt: DateTime.now(),
      regions: regions,
      tenantIds: tenantIds,
      healthGates: healthGates ?? defaultHealthGates,
    );

    await _rolloutRepository.save(state);
    return state;
  }

  /// Advance rollout to the next increment.
  Future<ReleaseResult> advanceRollout(String rolloutId) async {
    final rollout = await _rolloutRepository.getActiveRollout(rolloutId);
    if (rollout == null) {
      throw const ReleaseNotFoundException(
        message: 'Rollout not found',
      );
    }

    // Check health gates
    if (rollout.shouldRollback()) {
      return RollbackTriggered(
        releaseId: rollout.releaseId,
        rollbackTargetId: rolloutId,
        reason: 'Health gate triggered rollback',
      );
    }

    if (rollout.shouldPause()) {
      await _rolloutRepository.pauseRollout(rolloutId, 'Health gate triggered pause');
      return StagedRolloutPaused(
        releaseId: rollout.releaseId,
        currentPercentage: rollout.currentPercentage,
        reason: 'Health gate triggered pause',
      );
    }

    // Advance to next increment
    final nextIncrement = _getNextIncrement(rollout.currentPercentage);
    if (nextIncrement == null) {
      await _rolloutRepository.updatePercentage(rolloutId, rollout.targetPercentage);
      return ReleaseCompleted(
        releaseId: rollout.releaseId,
        deployedAt: DateTime.now(),
        rolloutPercentage: rollout.targetPercentage,
      );
    }

    await _rolloutRepository.updatePercentage(rolloutId, nextIncrement);
    return StagedRolloutPaused(
      releaseId: rollout.releaseId,
      currentPercentage: nextIncrement,
      reason: 'Rollout advanced to $nextIncrement%',
    );
  }

  /// Pause a rollout.
  Future<RolloutState> pauseRollout(String rolloutId, String reason) async {
    await _rolloutRepository.pauseRollout(rolloutId, reason);
    final rollout = await _rolloutRepository.getActiveRollout(rolloutId);
    if (rollout == null) {
      throw const ReleaseNotFoundException(
        message: 'Rollout not found',
      );
    }
    return rollout.pause(reason);
  }

  /// Resume a paused rollout.
  Future<RolloutState> resumeRollout(String rolloutId) async {
    await _rolloutRepository.resumeRollout(rolloutId);
    final rollout = await _rolloutRepository.getActiveRollout(rolloutId);
    if (rollout == null) {
      throw const ReleaseNotFoundException(
        message: 'Rollout not found',
      );
    }
    return rollout.resume();
  }

  /// Evaluate health gates with current metrics.
  Future<RolloutState> evaluateHealthGates({
    required String rolloutId,
    required Map<String, double> metrics,
  }) async {
    final rollout = await _rolloutRepository.getActiveRollout(rolloutId);
    if (rollout == null) {
      throw const ReleaseNotFoundException(
        message: 'Rollout not found',
      );
    }

    var updatedRollout = rollout;
    for (final entry in metrics.entries) {
      final gate = updatedRollout.healthGates[entry.key];
      if (gate != null) {
        final evaluatedGate = gate.evaluate(entry.value);
        updatedRollout = updatedRollout.copyWith(
          healthGates: {
            ...updatedRollout.healthGates,
            entry.key: evaluatedGate,
          },
        );
      }
    }

    await _rolloutRepository.save(updatedRollout);
    return updatedRollout;
  }

  int? _getNextIncrement(int currentPercentage) {
    for (final increment in rolloutIncrements) {
      if (increment > currentPercentage) return increment;
    }
    return null;
  }

  String _generateRolloutId() {
    return 'rlo_${DateTime.now().millisecondsSinceEpoch}';
  }
}
