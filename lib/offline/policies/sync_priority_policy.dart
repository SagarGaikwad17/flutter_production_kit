import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';

/// Sync priority policy — determines operation ordering and processing limits.
///
/// Design rationale:
/// - Critical operations (payments, deletions) sync before normal operations.
/// - Chunk sizes prevent memory exhaustion during large backlog processing.
/// - Per-priority limits prevent starvation (low-priority ops never sync).
/// - Max queue size prevents unbounded memory/disk growth.
class SyncPriorityPolicy {
  const SyncPriorityPolicy({
    this.maxQueueSize = 5000,
    this.criticalChunkSize = 5,
    this.highChunkSize = 10,
    this.normalChunkSize = 20,
    this.lowChunkSize = 50,
    this.backgroundChunkSize = 100,
    this.criticalPriorityWeight = 1000,
    this.highPriorityWeight = 500,
    this.normalPriorityWeight = 100,
    this.lowPriorityWeight = 10,
    this.backgroundPriorityWeight = 1,
    this.maxAgeBeforeExpiration = const Duration(days: 30),
    this.starvationPreventionThreshold = 100,
  });

  final int maxQueueSize;

  final int criticalChunkSize;
  final int highChunkSize;
  final int normalChunkSize;
  final int lowChunkSize;
  final int backgroundChunkSize;

  final int criticalPriorityWeight;
  final int highPriorityWeight;
  final int normalPriorityWeight;
  final int lowPriorityWeight;
  final int backgroundPriorityWeight;

  final Duration maxAgeBeforeExpiration;
  final int starvationPreventionThreshold;

  int getChunkSize(SyncPriority priority) {
    return switch (priority) {
      SyncPriority.critical => criticalChunkSize,
      SyncPriority.high => highChunkSize,
      SyncPriority.normal => normalChunkSize,
      SyncPriority.low => lowChunkSize,
      SyncPriority.background => backgroundChunkSize,
    };
  }

  int getWeight(SyncPriority priority) {
    return switch (priority) {
      SyncPriority.critical => criticalPriorityWeight,
      SyncPriority.high => highPriorityWeight,
      SyncPriority.normal => normalPriorityWeight,
      SyncPriority.low => lowPriorityWeight,
      SyncPriority.background => backgroundPriorityWeight,
    };
  }

  bool shouldExpire(DateTime createdAt) {
    return DateTime.now().difference(createdAt) > maxAgeBeforeExpiration;
  }

  static const SyncPriorityPolicy conservative = SyncPriorityPolicy(
    maxQueueSize: 2000,
    criticalChunkSize: 3,
    highChunkSize: 5,
    normalChunkSize: 10,
    lowChunkSize: 20,
    backgroundChunkSize: 50,
  );

  static const SyncPriorityPolicy aggressive = SyncPriorityPolicy(
    maxQueueSize: 10000,
    criticalChunkSize: 20,
    highChunkSize: 50,
    normalChunkSize: 100,
    lowChunkSize: 200,
    backgroundChunkSize: 500,
  );
}
