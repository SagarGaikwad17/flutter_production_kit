/// Sync trace entry — immutable audit log for sync operations.
///
/// Design rationale:
/// - Every sync attempt produces trace entries for observability.
/// - [operationId] links the trace to the original sync operation.
/// - [phase] identifies where in the sync pipeline the event occurred.
/// - [duration] measures how long each phase took (performance monitoring).
/// - [metadata] carries safe diagnostic data — NEVER sensitive payloads.
/// - Trace entries are persisted — survive app kills for post-mortem analysis.
class SyncTraceEntry {
  const SyncTraceEntry({
    required this.id,
    required this.operationId,
    required this.phase,
    required this.timestamp,
    this.duration,
    this.success = true,
    this.error,
    this.metadata = const {},
  });

  final String id;
  final String operationId;
  final SyncTracePhase phase;
  final DateTime timestamp;
  final Duration? duration;
  final bool success;
  final String? error;
  final Map<String, String> metadata;

  @override
  String toString() =>
      'SyncTraceEntry($id, op: $operationId, phase: ${phase.name}, '
      'success: $success${error != null ? ', error: $error' : ''})';
}

enum SyncTracePhase {
  enqueued,
  dequeued,
  permissionCheck,
  conflictCheck,
  idempotencyCheck,
  sending,
  serverResponse,
  conflictDetected,
  conflictResolved,
  completed,
  failed,
  retried,
  movedToPoison,
  expired,
  recovered,
}

/// Sync session summary — aggregate stats for a sync run.
class SyncSessionSummary {
  const SyncSessionSummary({
    required this.sessionId,
    required this.startedAt,
    required this.endedAt,
    required this.totalOperations,
    required this.successful,
    required this.failed,
    required this.conflicts,
    required this.duplicates,
    required this.poisoned,
    this.error,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int totalOperations;
  final int successful;
  final int failed;
  final int conflicts;
  final int duplicates;
  final int poisoned;
  final String? error;

  Duration get duration => endedAt.difference(startedAt);
  double get successRate => totalOperations > 0 ? successful / totalOperations : 0.0;

  @override
  String toString() =>
      'SyncSessionSummary($sessionId, '
      'total: $totalOperations, success: $successful, failed: $failed, '
      'conflicts: $conflicts, duration: $duration)';
}
