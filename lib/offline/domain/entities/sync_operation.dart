/// Immutable sync operation — the fundamental unit of offline work.
///
/// Design rationale:
/// - Every offline action (create, update, delete) is wrapped in a SyncOperation.
/// - [id] is a UUID generated at enqueue time — used for idempotency.
/// - [idempotencyKey] is derived from the operation content — prevents duplicate
///   submissions when the same action is enqueued multiple times.
/// - [priority] controls sync ordering (critical ops sync first).
/// - [dependsOn] enforces ordering (e.g., "create patient" before "add note").
/// - [metadata] carries minimal context — NO sensitive data (for safe logging).
/// - [createdAt] and [attemptedAt] enable staleness and retry tracking.
/// - [serverVersion] is set on successful sync — used for conflict detection.
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.resourceType,
    required this.action,
    required this.resourceId,
    required this.payload,
    required this.priority,
    this.idempotencyKey,
    this.dependsOn,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.createdAt,
    this.attemptedAt,
    this.lastError,
    this.serverVersion,
    this.metadata = const {},
    this.userId,
    this.branchId,
    this.tenantId,
  });

  final String id;
  final String resourceType;
  final SyncAction action;
  final String resourceId;
  final Map<String, dynamic> payload;
  final SyncPriority priority;
  final String? idempotencyKey;
  final List<String>? dependsOn;
  final int retryCount;
  final int maxRetries;
  final DateTime? createdAt;
  final DateTime? attemptedAt;
  final String? lastError;
  final String? serverVersion;
  final Map<String, String> metadata;
  final String? userId;
  final String? branchId;
  final String? tenantId;

  bool get isExpired {
    final created = createdAt;
    if (created == null) return false;
    return DateTime.now().difference(created) > const Duration(days: 30);
  }

  bool get canRetry => retryCount < maxRetries;

  SyncOperation copyWith({
    String? id,
    String? resourceType,
    SyncAction? action,
    String? resourceId,
    Map<String, dynamic>? payload,
    SyncPriority? priority,
    String? idempotencyKey,
    List<String>? dependsOn,
    int? retryCount,
    int? maxRetries,
    DateTime? attemptedAt,
    String? lastError,
    String? serverVersion,
    Map<String, String>? metadata,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      resourceType: resourceType ?? this.resourceType,
      action: action ?? this.action,
      resourceId: resourceId ?? this.resourceId,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      dependsOn: dependsOn ?? this.dependsOn,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt,
      attemptedAt: attemptedAt,
      lastError: lastError ?? this.lastError,
      serverVersion: serverVersion ?? this.serverVersion,
      metadata: metadata ?? this.metadata,
      userId: userId,
      branchId: branchId,
      tenantId: tenantId,
    );
  }

  @override
  String toString() =>
      'SyncOperation($id, $action:$resourceType/$resourceId, priority: ${priority.name}, retries: $retryCount)';
}

enum SyncAction { create, update, delete, replace }

enum SyncPriority {
  critical(level: 0),
  high(level: 10),
  normal(level: 50),
  low(level: 100),
  background(level: 200);

  const SyncPriority({required this.level});
  final int level;
}
