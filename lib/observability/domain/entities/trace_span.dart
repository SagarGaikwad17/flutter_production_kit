/// Trace span — a single operation within a distributed trace.
///
/// Design rationale:
/// - Spans form a tree structure (parent → children).
/// - [traceId] links all spans in a single request flow.
/// - [spanId] is unique within the trace.
/// - [parentSpanId] links to the parent span.
/// - [correlationId] links to external systems (payment gateways, etc.).
/// - NO sensitive data in attributes.
/// - Duration enables performance analysis.
/// - Status indicates success/failure for investigation.
class TraceSpan {
  const TraceSpan({
    required this.traceId,
    required this.spanId,
    required this.operation,
    required this.module,
    required this.startedAt,
    required this.status,
    this.parentSpanId,
    this.correlationId,
    this.endedAt,
    this.duration,
    this.attributes = const {},
    this.events = const [],
    this.error,
  });

  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String operation;
  final String module;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final TraceStatus status;
  final String? correlationId;
  final Map<String, String> attributes;
  final List<TraceEvent> events;
  final String? error;

  bool get isRoot => parentSpanId == null;
  bool get isComplete => endedAt != null;

  TraceSpan complete({
    required TraceStatus status,
    String? error,
    Map<String, String>? additionalAttributes,
  }) {
    final end = DateTime.now();
    return TraceSpan(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      operation: operation,
      module: module,
      startedAt: startedAt,
      endedAt: end,
      duration: end.difference(startedAt),
      status: status,
      correlationId: correlationId,
      attributes: {...attributes, ...?additionalAttributes},
      events: events,
      error: error,
    );
  }

  TraceSpan addEvent(TraceEvent event) {
    return TraceSpan(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      operation: operation,
      module: module,
      startedAt: startedAt,
      endedAt: endedAt,
      duration: duration,
      status: status,
      correlationId: correlationId,
      attributes: attributes,
      events: [...events, event],
      error: error,
    );
  }
}

enum TraceStatus {
  ok,
  error,
  cancelled,
}

/// Trace event — a timestamped annotation within a span.
class TraceEvent {
  const TraceEvent({
    required this.name,
    required this.timestamp,
    this.attributes = const {},
  });

  final String name;
  final DateTime timestamp;
  final Map<String, String> attributes;
}
