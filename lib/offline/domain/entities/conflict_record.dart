/// Conflict record — captures a detected sync conflict for resolution.
///
/// Design rationale:
/// - Conflicts occur when local and server versions of a resource diverge.
/// - [localVersion] and [serverVersion] contain the divergent payloads.
/// - [resolutionStrategy] records how the conflict was resolved (audit trail).
/// - [resolvedAt] and [resolvedBy] track who resolved it and when.
/// - Unresolved conflicts block sync for that resource until handled.
class ConflictRecord {
  const ConflictRecord({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.localVersion,
    required this.serverVersion,
    required this.localOperationId,
    required this.detectedAt,
    this.resolutionStrategy,
    this.resolvedPayload,
    this.resolvedAt,
    this.resolvedBy,
    this.metadata = const {},
  });

  final String id;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic> localVersion;
  final Map<String, dynamic> serverVersion;
  final String localOperationId;
  final DateTime detectedAt;
  final ConflictResolutionStrategy? resolutionStrategy;
  final Map<String, dynamic>? resolvedPayload;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final Map<String, String> metadata;

  bool get isResolved => resolutionStrategy != null && resolvedAt != null;

  ConflictRecord copyWithResolution({
    required ConflictResolutionStrategy strategy,
    required Map<String, dynamic> resolvedPayload,
    required DateTime resolvedAt,
    String? resolvedBy,
  }) {
    return ConflictRecord(
      id: id,
      resourceType: resourceType,
      resourceId: resourceId,
      localVersion: localVersion,
      serverVersion: serverVersion,
      localOperationId: localOperationId,
      detectedAt: detectedAt,
      resolutionStrategy: strategy,
      resolvedPayload: resolvedPayload,
      resolvedAt: resolvedAt,
      resolvedBy: resolvedBy,
      metadata: metadata,
    );
  }

  @override
  String toString() =>
      'ConflictRecord($id, $resourceType/$resourceId, detected: $detectedAt, '
      'resolved: ${isResolved ? resolutionStrategy!.name : "pending"})';
}

enum ConflictResolutionStrategy {
  serverWins,
  clientWins,
  mergeFields,
  manualResolution,
  localDiscarded,
}

enum ConflictSeverity {
  low,
  medium,
  high,
  critical,
}
