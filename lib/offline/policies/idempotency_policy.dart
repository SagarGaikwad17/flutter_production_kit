import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';

/// Idempotency policy — ensures sync operations are safe to retry.
///
/// Design rationale:
/// - Every sync operation MUST have an idempotency key.
/// - The key is derived from: resourceType + resourceId + action + content hash.
/// - If the same key was already synced, the operation is skipped (not re-executed).
/// - Idempotency keys are stored persistently — survive app restarts.
/// - Key TTL prevents unbounded storage growth.
class IdempotencyPolicy {
  const IdempotencyPolicy({
    this.keyTtl = const Duration(days: 7),
    this.hashAlgorithm = 'sha256',
    this.includePayloadInHash = true,
  });

  final Duration keyTtl;
  final String hashAlgorithm;
  final bool includePayloadInHash;

  /// Generate an idempotency key from an operation.
  ///
  /// The key uniquely identifies the INTENT of the operation.
  /// Two operations with the same key represent the same user action
  /// and should not both be executed.
  String generateKey(SyncOperation operation) {
    final components = [
      operation.resourceType,
      operation.resourceId,
      operation.action.name,
      if (includePayloadInHash) _simpleHash(operation.payload.toString()),
      operation.createdAt?.millisecondsSinceEpoch.toString() ?? '0',
    ].join(':');

    return 'sync_${_simpleHash(components)}';
  }

  /// Generate a key from raw operation parameters (for deduplication at enqueue).
  String generateKeyFromParams({
    required String resourceType,
    required String resourceId,
    required SyncAction action,
    Map<String, dynamic>? payload,
  }) {
    final components = [
      resourceType,
      resourceId,
      action.name,
      if (includePayloadInHash && payload != null)
        _simpleHash(payload.toString()),
    ].join(':');

    return 'sync_${_simpleHash(components)}';
  }

  /// Check if a key is still valid (not expired).
  bool isKeyValid(DateTime storedAt) {
    return DateTime.now().difference(storedAt) < keyTtl;
  }

  /// Simple hash function for key generation.
  /// In production, use crypto package for SHA-256.
  String _simpleHash(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs().toRadixString(36);
  }
}
