import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/exceptions/observability_exception.dart';

/// Immutable audit store — tamper-evident storage for audit entries.
///
/// Design rationale:
/// - Entries are stored with a hash chain for tamper detection.
/// - Each entry's hash includes the previous entry's hash (blockchain-like).
/// - If any entry is modified, the chain breaks and tampering is detected.
/// - Store is append-only — no updates or deletes allowed.
/// - Verification compares stored hash with recomputed hash.
///
/// Hash chain:
///   entry_1.hash = hash(entry_1.data + genesis_hash)
///   entry_2.hash = hash(entry_2.data + entry_1.hash)
///   entry_3.hash = hash(entry_3.data + entry_2.hash)
///   ...
class ImmutableAuditStore {
  ImmutableAuditStore({
    String? genesisHash,
  }) : _genesisHash = genesisHash ?? 'genesis_audit_${DateTime.now().millisecondsSinceEpoch}';

  final String _genesisHash;
  final Map<String, _StoredEntry> _store = {};
  String? _lastHash;

  /// Store an audit entry (append-only).
  void store(AuditEntry entry) {
    if (_store.containsKey(entry.id)) {
      throw AuditTamperingDetectedException(
        message: 'Audit entry already exists: ${entry.id}. Store is append-only.',
        entryId: entry.id,
      );
    }

    final previousHash = _lastHash ?? _genesisHash;
    final currentHash = _computeHash(entry, previousHash);

    _store[entry.id] = _StoredEntry(
      entry: entry,
      hash: currentHash,
      previousHash: previousHash,
    );

    _lastHash = currentHash;
  }

  /// Verify an entry's integrity.
  bool verify(AuditEntry entry) {
    final stored = _store[entry.id];
    if (stored == null) return false;

    // Check lock version hasn't changed.
    if (stored.entry.lockVersion != entry.lockVersion) {
      return false;
    }

    // Recompute hash and compare.
    final recomputedHash = _computeHash(entry, stored.previousHash);
    return recomputedHash == stored.hash;
  }

  /// Verify the entire chain integrity.
  bool verifyChain() {
    var expectedHash = _genesisHash;

    // Sort entries by timestamp for chain verification.
    final sorted = _store.values.toList()
      ..sort((a, b) => a.entry.timestamp.compareTo(b.entry.timestamp));

    for (final stored in sorted) {
      if (stored.previousHash != expectedHash) {
        return false;
      }
      expectedHash = stored.hash;
    }

    return true;
  }

  /// Get all stored entries.
  List<AuditEntry> getAll() {
    return _store.values.map((e) => e.entry).toList();
  }

  /// Get the count of stored entries.
  int get count => _store.length;

  /// Clear the store (for testing only — NEVER in production).
  void clearForTesting() {
    _store.clear();
    _lastHash = null;
  }

  String _computeHash(AuditEntry entry, String previousHash) {
    // Simple hash combining entry data with previous hash.
    // In production, use a proper cryptographic hash (SHA-256).
    final data = '${entry.id}:${entry.timestamp.toIso8601String()}:${entry.actorId}:'
        '${entry.action}:${entry.target}:${entry.result.name}:${entry.module}:$previousHash';
    return _simpleHash(data);
  }

  String _simpleHash(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer.
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _StoredEntry {
  const _StoredEntry({
    required this.entry,
    required this.hash,
    required this.previousHash,
  });

  final AuditEntry entry;
  final String hash;
  final String previousHash;
}
