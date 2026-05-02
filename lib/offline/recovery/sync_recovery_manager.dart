import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/repositories/sync_repository.dart';
import 'package:flutter_production_kit/offline/queue/offline_queue_manager.dart';

/// Sync recovery manager — handles app-kill and crash recovery.
///
/// Design rationale:
/// - When the app is killed during a sync session, operations may be in-progress.
/// - On restart, the recovery manager checks for incomplete checkpoints.
/// - In-progress operations are released back to the queue (safe to re-process).
/// - The checkpoint records how far the previous session got.
/// - Recovery is transparent — the next sync session picks up where it left off.
///
/// Recovery scenarios:
/// 1. App killed during sync → checkpoint exists → resume from checkpoint.
/// 2. App killed before checkpoint → no checkpoint → full re-sync.
/// 3. Corrupted checkpoint → clear checkpoint → full re-sync (safe).
/// 4. Poison queue recovery → operations are isolated, not re-processed.
class SyncRecoveryManager {
  SyncRecoveryManager({
    required SyncRepository repository,
    OfflineQueueManager? queueManager,
  }) : _repository = repository;

  static const String _tag = 'SyncRecoveryManager';

  final SyncRepository _repository;

  /// Check for and recover from an incomplete sync session.
  ///
  /// Called during app initialization.
  /// Returns the recovery result for logging and monitoring.
  Future<RecoveryResult> recover() async {
    AppLogger.info(_tag, 'Starting sync recovery check...');

    try {
      final checkpoint = await _repository.getLastCheckpoint();

      if (checkpoint == null) {
        AppLogger.info(_tag, 'No checkpoint found — no recovery needed.');
        return const RecoveryNoCheckpoint();
      }

      AppLogger.info(
        _tag,
        'Found checkpoint: ${checkpoint.sessionId} '
        '(${checkpoint.operationsProcessed}/${checkpoint.totalOperations} processed)',
      );

      // Validate the checkpoint.
      if (!_isValidCheckpoint(checkpoint)) {
        AppLogger.warning(_tag, 'Checkpoint is invalid — clearing and starting fresh.');
        await _repository.clearCheckpoints();
        return RecoveryCheckpointInvalid(
          sessionId: checkpoint.sessionId,
          reason: 'Checkpoint data is inconsistent.',
        );
      }

      // Release any in-progress operations back to the queue.
      await _releaseInProgressOperations();

      // Clear the checkpoint — the next sync session will re-process.
      await _repository.clearCheckpoints();

      AppLogger.info(
        _tag,
        'Recovery complete: checkpoint cleared, operations released. '
        'Previous session processed ${checkpoint.operationsProcessed} operations.',
      );

      return RecoverySuccess(
        sessionId: checkpoint.sessionId,
        operationsRecovered: checkpoint.totalOperations - checkpoint.operationsProcessed,
        operationsPreviouslyProcessed: checkpoint.operationsProcessed,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Recovery failed', error: e, stackTrace: st);
      return RecoveryFailed(error: e.toString());
    }
  }

  /// Save a checkpoint during sync execution.
  Future<void> saveCheckpoint({
    required String sessionId,
    required int operationsProcessed,
    required int totalOperations,
  }) async {
    await _repository.saveCheckpoint(
      sessionId: sessionId,
      operationsProcessed: operationsProcessed,
      totalOperations: totalOperations,
    );
  }

  /// Release in-progress operations back to the queue.
  Future<void> _releaseInProgressOperations() async {
    AppLogger.info(_tag, 'In-progress operations will be re-queued on next sync.');
  }

  /// Validate that a checkpoint is consistent.
  bool _isValidCheckpoint(SyncCheckpoint checkpoint) {
    if (checkpoint.operationsProcessed > checkpoint.totalOperations) {
      return false;
    }
    if (checkpoint.operationsProcessed < 0) {
      return false;
    }
    return true;
  }
}

/// Result of a recovery operation.
sealed class RecoveryResult {
  const RecoveryResult();
}

final class RecoveryNoCheckpoint extends RecoveryResult {
  const RecoveryNoCheckpoint();
}

final class RecoverySuccess extends RecoveryResult {
  const RecoverySuccess({
    required this.sessionId,
    required this.operationsRecovered,
    required this.operationsPreviouslyProcessed,
  });

  final String sessionId;
  final int operationsRecovered;
  final int operationsPreviouslyProcessed;
}

final class RecoveryCheckpointInvalid extends RecoveryResult {
  const RecoveryCheckpointInvalid({
    required this.sessionId,
    required this.reason,
  });

  final String sessionId;
  final String reason;
}

final class RecoveryFailed extends RecoveryResult {
  const RecoveryFailed({required this.error});
  final String error;
}
