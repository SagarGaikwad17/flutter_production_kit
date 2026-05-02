/// Sync exception hierarchy — explicit error types for offline sync operations.
///
/// Design rationale:
/// - Each exception type maps to a specific recovery strategy.
/// - [SyncOperationException] wraps a failing operation with context.
/// - [QueueException] covers queue-level failures (storage, corruption).
/// - [ConflictException] covers conflict resolution failures.
/// - [RecoveryException] covers checkpoint and recovery failures.
/// - Exceptions carry operation IDs and resource types — safe for logging.
/// - NO sensitive payload data in exception messages.

/// Base exception for all sync-related errors.
sealed class SyncException implements Exception {
  const SyncException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// A specific sync operation failed.
final class SyncOperationException extends SyncException {
  const SyncOperationException({
    required this.operationId,
    required this.resourceType,
    required this.action,
    required super.message,
    super.cause,
  });

  final String operationId;
  final String resourceType;
  final String action;
}

/// The offline queue encountered a critical error.
final class QueueException extends SyncException {
  const QueueException({required super.message, super.cause});
}

/// Queue storage is corrupted — requires rebuild.
final class QueueCorruptedException extends QueueException {
  const QueueCorruptedException({required super.message, super.cause});
}

/// Queue exceeds the maximum safe size — new operations rejected.
final class QueueOverflowException extends QueueException {
  const QueueOverflowException({
    required super.message,
    this.currentSize,
    this.maxSize,
  });
  final int? currentSize;
  final int? maxSize;
}

/// Conflict resolution failed or was rejected.
final class ConflictException extends SyncException {
  const ConflictException({
    required this.conflictId,
    required this.resourceType,
    required this.resourceId,
    required super.message,
    super.cause,
  });

  final String conflictId;
  final String resourceType;
  final String resourceId;
}

/// Recovery from app-kill or crash failed.
final class RecoveryException extends SyncException {
  const RecoveryException({required super.message, super.cause});
}

/// Checkpoint is invalid — recovery cannot proceed safely.
final class CheckpointInvalidException extends RecoveryException {
  const CheckpointInvalidException({required super.message, super.cause});
}

/// Permission revalidation failed during sync.
final class SyncPermissionException extends SyncException {
  const SyncPermissionException({
    required this.operationId,
    required this.requiredPermission,
    required super.message,
  });

  final String operationId;
  final String requiredPermission;
}
