import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Billing trace — structured logging for billing transitions.
///
/// Design rationale:
/// - Every billing transition is traced for observability.
/// - Traces are structured — easy to query in production tools.
/// - NO sensitive financial data in traces.
/// - Traces include: transition type, states, timing, idempotency.
class BillingTrace {
  BillingTrace({
    String? tag,
  }) : _tag = tag ?? 'BillingTrace';

  final String _tag;
  final List<BillingTraceEntry> _entries = [];

  /// Record a billing transition trace.
  void record({
    required String subscriptionId,
    required String transition,
    required String fromState,
    required String toState,
    required bool success,
    String? error,
    String? idempotencyKey,
    Map<String, String>? metadata,
  }) {
    final entry = BillingTraceEntry(
      id: 'trace_${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      transition: transition,
      fromState: fromState,
      toState: toState,
      timestamp: DateTime.now(),
      success: success,
      error: error,
      idempotencyKey: idempotencyKey,
      metadata: metadata ?? {},
    );

    _entries.add(entry);

    if (success) {
      AppLogger.info(_tag, 'Trace: $subscriptionId $transition ($fromState → $toState)');
    } else {
      AppLogger.error(
        _tag,
        'Trace: $subscriptionId $transition FAILED ($fromState → $toState)',
        error: error ?? 'Unknown error',
      );
    }
  }

  /// Record a duplicate event detection.
  void recordDuplicate({
    required String idempotencyKey,
    required BillingEventType eventType,
  }) {
    AppLogger.warning(
      _tag,
      'Duplicate event detected: $idempotencyKey (${eventType.name})',
    );
  }

  /// Record a grace period entry/exit.
  void recordGracePeriod({
    required String subscriptionId,
    required bool isEntering,
    required int failedAttempts,
    DateTime? graceEndsAt,
  }) {
    final action = isEntering ? 'entered' : 'exited';
    AppLogger.info(
      _tag,
      'Grace period $action: $subscriptionId '
      '(attempts: $failedAttempts${graceEndsAt != null ? ', ends: $graceEndsAt' : ''})',
    );
  }

  /// Record an entitlement change.
  void recordEntitlementChange({
    required String subscriptionId,
    required List<String> added,
    required List<String> removed,
    required String reason,
  }) {
    AppLogger.info(
      _tag,
      'Entitlement change: $subscriptionId '
      '(+${added.length}, -${removed.length}) — $reason',
    );
  }

  /// Get all trace entries.
  List<BillingTraceEntry> getEntries() {
    return List.unmodifiable(_entries);
  }

  /// Clear trace entries.
  void clear() {
    _entries.clear();
  }
}

class BillingTraceEntry {
  const BillingTraceEntry({
    required this.id,
    required this.subscriptionId,
    required this.transition,
    required this.fromState,
    required this.toState,
    required this.timestamp,
    required this.success,
    this.error,
    this.idempotencyKey,
    this.metadata = const {},
  });

  final String id;
  final String subscriptionId;
  final String transition;
  final String fromState;
  final String toState;
  final DateTime timestamp;
  final bool success;
  final String? error;
  final String? idempotencyKey;
  final Map<String, String> metadata;
}
