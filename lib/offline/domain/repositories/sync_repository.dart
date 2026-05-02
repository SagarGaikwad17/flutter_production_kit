import 'package:flutter_production_kit/offline/domain/entities/conflict_record.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_status.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_trace.dart';

/// Abstract repository for sync data — separates domain from persistence.
///
/// Design rationale:
/// - The domain layer should not depend on SQLite, Hive, or any storage package.
/// - This interface defines the contract that any persistence implementation must fulfill.
/// - Operations are batch-capable for performance (bulk enqueue, bulk status update).
/// - Conflict records and trace entries are stored separately from operations.
abstract class SyncRepository {
  const SyncRepository();

  // ── Operation Storage ──────────────────────────────────────────────────────

  /// Persist a new sync operation to the queue.
  Future<void> enqueueOperation(SyncOperation operation);

  /// Persist multiple operations atomically.
  Future<void> enqueueOperations(List<SyncOperation> operations);

  /// Get the next batch of operations ready for sync, ordered by priority.
  Future<List<SyncOperation>> getNextBatch({int limit = 20});

  /// Get a specific operation by ID.
  Future<SyncOperation?> getOperation(String operationId);

  /// Update an operation's status and metadata.
  Future<void> updateOperation(SyncOperation operation);

  /// Bulk update operation statuses.
  Future<void> updateOperationStatuses(Map<String, SyncStatus> statusMap);

  /// Mark an operation as completed.
  Future<void> markCompleted(String operationId, {String? serverVersion});

  /// Mark an operation as failed with error details.
  Future<void> markFailed(String operationId, {String? error});

  /// Move an operation to the poison queue.
  Future<void> moveToPoisonQueue(String operationId, {String? reason});

  /// Delete completed operations older than [olderThan].
  Future<int> purgeCompleted({DateTime? olderThan});

  /// Get the total count of pending operations.
  Future<int> getPendingCount();

  /// Get operations for a specific resource (for conflict detection).
  Future<List<SyncOperation>> getOperationsForResource({
    required String resourceType,
    required String resourceId,
  });

  // ── Conflict Storage ───────────────────────────────────────────────────────

  /// Store a conflict record.
  Future<void> storeConflict(ConflictRecord conflict);

  /// Get unresolved conflicts.
  Future<List<ConflictRecord>> getUnresolvedConflicts();

  /// Update a conflict with resolution data.
  Future<void> resolveConflict(ConflictRecord resolved);

  /// Get conflicts for a specific resource.
  Future<List<ConflictRecord>> getConflictsForResource({
    required String resourceType,
    required String resourceId,
  });

  // ── Trace Storage ──────────────────────────────────────────────────────────

  /// Store a trace entry.
  Future<void> storeTraceEntry(SyncTraceEntry entry);

  /// Store multiple trace entries atomically.
  Future<void> storeTraceEntries(List<SyncTraceEntry> entries);

  /// Get trace entries for an operation.
  Future<List<SyncTraceEntry>> getOperationTraces(String operationId);

  // ── Idempotency ────────────────────────────────────────────────────────────

  /// Check if an idempotency key has already been synced.
  Future<String?> getIdempotencyResult(String idempotencyKey);

  /// Store an idempotency key with its result.
  Future<void> storeIdempotencyResult({
    required String idempotencyKey,
    required String operationId,
    required DateTime syncedAt,
  });

  // ── Checkpoint ─────────────────────────────────────────────────────────────

  /// Save a recovery checkpoint.
  Future<void> saveCheckpoint({
    required String sessionId,
    required int operationsProcessed,
    required int totalOperations,
  });

  /// Get the last saved checkpoint.
  Future<SyncCheckpoint?> getLastCheckpoint();

  /// Clear all checkpoints.
  Future<void> clearCheckpoints();

  // ── Maintenance ────────────────────────────────────────────────────────────

  /// Initialize the storage (create tables, run migrations).
  Future<void> initialize();

  /// Close the storage connection.
  Future<void> close();

  /// Get storage health status.
  Future<SyncStorageHealth> getHealth();
}

/// Recovery checkpoint — saved state for crash recovery.
class SyncCheckpoint {
  const SyncCheckpoint({
    required this.sessionId,
    required this.savedAt,
    required this.operationsProcessed,
    required this.totalOperations,
  });

  final String sessionId;
  final DateTime savedAt;
  final int operationsProcessed;
  final int totalOperations;

  double get progress => totalOperations > 0 ? operationsProcessed / totalOperations : 0.0;
}

/// Storage health status.
class SyncStorageHealth {
  const SyncStorageHealth({
    required this.isHealthy,
    this.operationCount,
    this.queueSizeBytes,
    this.lastError,
  });

  final bool isHealthy;
  final int? operationCount;
  final int? queueSizeBytes;
  final String? lastError;
}
