import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/exceptions/observability_exception.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';
import 'package:flutter_production_kit/observability/audits/immutable_audit_store.dart';

/// Audit trail engine — manages immutable audit recording and investigation.
///
/// Design rationale:
/// - All audit entries are immutable — once recorded, they cannot be changed.
/// - Entries are validated before recording to ensure compliance.
/// - Cross-module audit linking via correlation IDs.
/// - Tamper detection via lock version tracking.
/// - Integration with ImmutableAuditStore for append-only storage.
///
/// Audit flow:
///   1. Create audit entry with required fields.
///   2. Validate entry (no sensitive data, required fields present).
///   3. Record to ImmutableAuditStore.
///   4. Return entry ID for investigation linking.
///   5. On read, verify lock version to detect tampering.
class AuditTrailEngine {
  AuditTrailEngine({
    required AuditRepository auditRepository,
    ImmutableAuditStore? auditStore,
  })  : _auditRepository = auditRepository,
        _auditStore = auditStore ?? ImmutableAuditStore();

  final AuditRepository _auditRepository;
  final ImmutableAuditStore _auditStore;

  /// Record an audit entry.
  Future<String> record({
    required String actorId,
    required String action,
    required String target,
    required AuditResult result,
    required String module,
    String? correlationId,
    String? reason,
    Map<String, String>? metadata,
    AuditRetentionCategory retentionCategory = AuditRetentionCategory.standard,
  }) async {
    final entry = AuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      actorId: actorId,
      action: action,
      target: target,
      result: result,
      module: module,
      correlationId: correlationId,
      reason: reason,
      metadata: metadata ?? {},
      retentionCategory: retentionCategory,
    );

    // Validate entry.
    _validateEntry(entry);

    // Store in immutable store.
    _auditStore.store(entry);

    // Persist to repository.
    await _auditRepository.saveAuditEntry(entry);

    return entry.id;
  }

  /// Record a billing audit entry (7-year retention).
  Future<String> recordBilling({
    required String actorId,
    required String action,
    required String target,
    required AuditResult result,
    String? correlationId,
    String? reason,
    Map<String, String>? metadata,
  }) {
    return record(
      actorId: actorId,
      action: action,
      target: target,
      result: result,
      module: 'billing',
      correlationId: correlationId,
      reason: reason,
      metadata: metadata,
      retentionCategory: AuditRetentionCategory.billing,
    );
  }

  /// Record a security audit entry (1-year retention).
  Future<String> recordSecurity({
    required String actorId,
    required String action,
    required String target,
    required AuditResult result,
    String? correlationId,
    String? reason,
    Map<String, String>? metadata,
  }) {
    return record(
      actorId: actorId,
      action: action,
      target: target,
      result: result,
      module: 'security',
      correlationId: correlationId,
      reason: reason,
      metadata: metadata,
      retentionCategory: AuditRetentionCategory.security,
    );
  }

  /// Record a compliance audit entry (10-year retention).
  Future<String> recordCompliance({
    required String actorId,
    required String action,
    required String target,
    required AuditResult result,
    String? correlationId,
    String? reason,
    Map<String, String>? metadata,
  }) {
    return record(
      actorId: actorId,
      action: action,
      target: target,
      result: result,
      module: 'compliance',
      correlationId: correlationId,
      reason: reason,
      metadata: metadata,
      retentionCategory: AuditRetentionCategory.compliance,
    );
  }

  /// Get audit entries by correlation ID (for investigation).
  Future<List<AuditEntry>> getByCorrelationId(String correlationId) {
    return _auditRepository.getEntriesByCorrelationId(correlationId);
  }

  /// Get audit entries by actor (for user investigation).
  Future<List<AuditEntry>> getByActor(String actorId) {
    return _auditRepository.getEntriesByActor(actorId);
  }

  /// Get audit entries by action (for action investigation).
  Future<List<AuditEntry>> getByAction(String action) {
    return _auditRepository.getEntriesByAction(action);
  }

  /// Get audit entries within a time range.
  Future<List<AuditEntry>> getByTimeRange({
    required DateTime start,
    required DateTime end,
    String? module,
  }) {
    return _auditRepository.getEntriesByTimeRange(start: start, end: end, module: module);
  }

  /// Verify an entry hasn't been tampered with.
  bool verifyIntegrity(AuditEntry entry) {
    return _auditStore.verify(entry);
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  void _validateEntry(AuditEntry entry) {
    if (entry.actorId.isEmpty) {
      throw AuditRecordingFailedException(
        message: 'Audit entry requires a non-empty actorId.',
        entryId: entry.id,
        module: entry.module,
      );
    }

    if (entry.action.isEmpty) {
      throw AuditRecordingFailedException(
        message: 'Audit entry requires a non-empty action.',
        entryId: entry.id,
        module: entry.module,
      );
    }

    // Check for sensitive data in metadata.
    for (final key in entry.metadata.keys) {
      if (_isSensitiveField(key)) {
        throw AuditRecordingFailedException(
          message: 'Audit entry contains sensitive field: $key',
          entryId: entry.id,
          module: entry.module,
        );
      }
    }
  }

  bool _isSensitiveField(String key) {
    final lower = key.toLowerCase();
    const patterns = ['token', 'secret', 'password', 'card', 'ssn', 'email', 'phone'];
    return patterns.any((p) => lower.contains(p));
  }
}
