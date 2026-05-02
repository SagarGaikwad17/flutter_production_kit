import 'package:flutter_production_kit/observability/domain/entities/trace_span.dart';
import 'package:flutter_production_kit/observability/domain/exceptions/observability_exception.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';
import 'package:flutter_production_kit/observability/tracing/correlation_id_manager.dart';

/// Trace engine — manages distributed tracing across modules.
///
/// Design rationale:
/// - Traces link operations across auth, network, permissions, billing, etc.
/// - Each trace has a unique traceId and multiple spans (tree structure).
/// - Correlation IDs link traces to external systems (payment gateways, etc.).
/// - Spans are started and completed explicitly for accurate duration tracking.
/// - All spans are persisted for investigation and performance analysis.
///
/// Trace flow:
///   1. Start trace at operation entry point.
///   2. Create child spans for sub-operations.
///   3. Complete spans with status (ok/error/cancelled).
///   4. Link to correlation ID for cross-system investigation.
///   5. Persist all spans to TraceRepository.
///
/// Investigation use cases:
///   - Payment failure: trace payment → gateway → webhook → entitlement.
///   - Permission denial: trace auth → role check → entitlement → decision.
///   - Sync data loss: trace local save → queue → sync → conflict → resolution.
class TraceEngine {
  TraceEngine({
    required TraceRepository traceRepository,
    required CorrelationIdManager correlationIdManager,
  })  : _traceRepository = traceRepository,
        _correlationIdManager = correlationIdManager;

  final TraceRepository _traceRepository;
  final CorrelationIdManager _correlationIdManager;
  final Map<String, TraceSpan> _activeSpans = {};

  /// Start a new trace.
  TraceSpan startTrace({
    required String operation,
    required String module,
    String? correlationId,
    Map<String, String>? attributes,
  }) {
    final traceId = correlationId ?? _correlationIdManager.generate();
    final spanId = 'span_${DateTime.now().millisecondsSinceEpoch}';

    final span = TraceSpan(
      traceId: traceId,
      spanId: spanId,
      operation: operation,
      module: module,
      startedAt: DateTime.now(),
      status: TraceStatus.ok,
      correlationId: correlationId,
      attributes: attributes ?? {},
    );

    _activeSpans[spanId] = span;
    _correlationIdManager.setCurrent(traceId);

    return span;
  }

  /// Start a child span within an existing trace.
  TraceSpan startChildSpan({
    required String parentSpanId,
    required String operation,
    required String module,
    Map<String, String>? attributes,
  }) {
    final parent = _activeSpans[parentSpanId];
    if (parent == null) {
      throw TraceCreationFailedException(
        message: 'Parent span not found: $parentSpanId',
        operation: operation,
      );
    }

    final spanId = 'span_${DateTime.now().millisecondsSinceEpoch}';

    final span = TraceSpan(
      traceId: parent.traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      operation: operation,
      module: module,
      startedAt: DateTime.now(),
      status: TraceStatus.ok,
      correlationId: parent.correlationId,
      attributes: attributes ?? {},
    );

    _activeSpans[spanId] = span;
    return span;
  }

  /// Complete a span.
  Future<void> completeSpan({
    required String spanId,
    required TraceStatus status,
    String? error,
    Map<String, String>? additionalAttributes,
  }) async {
    final span = _activeSpans[spanId];
    if (span == null) {
      throw TraceSpanCompletionFailedException(
        message: 'Span not found: $spanId',
        spanId: spanId,
      );
    }

    final completed = span.complete(
      status: status,
      error: error,
      additionalAttributes: additionalAttributes,
    );

    await _traceRepository.saveSpan(completed);
    _activeSpans.remove(spanId);
  }

  /// Add an event to a span.
  void addEvent({
    required String spanId,
    required String eventName,
    Map<String, String>? attributes,
  }) {
    final span = _activeSpans[spanId];
    if (span == null) return;

    final event = TraceEvent(
      name: eventName,
      timestamp: DateTime.now(),
      attributes: attributes ?? {},
    );

    _activeSpans[spanId] = span.addEvent(event);
  }

  /// Get all spans for a trace.
  Future<List<TraceSpan>> getTrace(String traceId) {
    return _traceRepository.getSpansByTraceId(traceId);
  }

  /// Get traces by correlation ID.
  Future<List<TraceSpan>> getByCorrelationId(String correlationId) {
    return _traceRepository.getSpansByCorrelationId(correlationId);
  }

  /// Get traces by module.
  Future<List<TraceSpan>> getByModule(String module) {
    return _traceRepository.getSpansByModule(module);
  }

  /// Get the current correlation ID.
  String? getCurrentCorrelationId() {
    return _correlationIdManager.current;
  }

  /// Clear active spans (call at end of operation).
  void clearActiveSpans() {
    _activeSpans.clear();
  }

  /// Get active span count.
  int get activeSpanCount => _activeSpans.length;
}
