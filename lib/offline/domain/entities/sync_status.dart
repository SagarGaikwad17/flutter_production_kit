/// Sync status — the state machine for individual sync operations.
///
/// Design rationale:
/// Each operation goes through a well-defined lifecycle.
/// Transitions are one-way (except pending→ready→pending on retry).
/// The status determines what the sync engine should do next.
///
/// Lifecycle:
///   pending → ready → inProgress → completed
///   pending → ready → inProgress → failed → (retry) → pending
///   failed → poisonQueue (after max retries)
///   pending → conflict → (resolution) → ready
///   pending → expired (stale operations)
enum SyncStatus {
  pending,
  ready,
  inProgress,
  completed,
  failed,
  conflict,
  poisonQueue,
  expired,
}

/// Queue state — the overall state of the offline queue.
///
/// Design rationale:
/// - The queue has its own state machine separate from individual operations.
/// - [paused] means sync is temporarily halted (user action, network flap).
/// - [syncing] means a sync session is actively running.
/// - [draining] means the queue is being processed after a long offline period.
/// - [error] means a critical queue-level error occurred (storage, corruption).
enum QueueState {
  idle,
  syncing,
  draining,
  paused,
  error,
  destroyed,
}

/// Sync engine state — the overall state of the sync system.
enum SyncEngineState {
  initialized,
  running,
  paused,
  recovering,
  stopped,
}

/// Failure classification — explicit categorization of sync failures.
///
/// Design rationale:
/// - Not all failures are equal. The classification determines recovery behavior.
/// - [retryable] failures trigger automatic retry with backoff.
/// - [permanent] failures are terminal — the operation cannot succeed.
/// - [permissionDenied] means the user lost access — operation is rejected.
/// - [duplicatePrevented] means idempotency caught a double-submit.
/// - [conflictRequiresManual] needs human intervention.
/// - [staleRejected] means the operation is too old to be valid.
/// - [versionMismatch] means the server version doesn't match expectations.
/// - [poisonIsolated] means the operation has been moved to the poison queue.
sealed class SyncFailure {
  const SyncFailure({required this.message, this.operationId});
  final String message;
  final String? operationId;
}

final class SyncFailureRetryable extends SyncFailure {
  const SyncFailureRetryable({
    required super.message,
    super.operationId,
    this.retryAfter,
    this.httpStatusCode,
  });
  final DateTime? retryAfter;
  final int? httpStatusCode;
}

final class SyncFailurePermanent extends SyncFailure {
  const SyncFailurePermanent({
    required super.message,
    super.operationId,
  });
}

final class SyncFailurePermissionDenied extends SyncFailure {
  const SyncFailurePermissionDenied({
    required super.message,
    super.operationId,
    this.requiredPermission,
  });
  final String? requiredPermission;
}

final class SyncFailureDuplicatePrevented extends SyncFailure {
  const SyncFailureDuplicatePrevented({
    required super.message,
    super.operationId,
    this.originalOperationId,
    this.originalSyncedAt,
  });
  final String? originalOperationId;
  final DateTime? originalSyncedAt;
}

final class SyncFailureConflictRequiresManual extends SyncFailure {
  const SyncFailureConflictRequiresManual({
    required super.message,
    super.operationId,
    required this.conflictId,
  });
  final String conflictId;
}

final class SyncFailureStaleRejected extends SyncFailure {
  const SyncFailureStaleRejected({
    required super.message,
    super.operationId,
    this.operationAge,
  });
  final Duration? operationAge;
}

final class SyncFailureVersionMismatch extends SyncFailure {
  const SyncFailureVersionMismatch({
    required super.message,
    super.operationId,
    this.expectedVersion,
    this.serverVersion,
  });
  final String? expectedVersion;
  final String? serverVersion;
}

final class SyncFailurePoisonIsolated extends SyncFailure {
  const SyncFailurePoisonIsolated({
    required super.message,
    super.operationId,
    this.attempts,
  });
  final int? attempts;
}
