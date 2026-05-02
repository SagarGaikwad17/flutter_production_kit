/// Tenant trace engine — distributed tracing for tenant-scoped operations.
///
/// Design rationale:
/// - Propagates correlation IDs across tenant operations.
/// - Creates trace spans for tenant resolution, context management, and isolation checks.
/// - Integrates with observability tracing layer.
/// - Supports trace context extraction/injection for HTTP requests.
class TenantTraceEngine {
  const TenantTraceEngine();

  /// Create a new trace context for a tenant operation.
  TenantTraceContext createTraceContext({
    required String tenantId,
    required String operation,
    String? parentTraceId,
    String? userId,
  }) {
    return TenantTraceContext(
      traceId: _generateTraceId(),
      tenantId: tenantId,
      operation: operation,
      parentTraceId: parentTraceId,
      userId: userId,
      startTime: DateTime.now(),
    );
  }

  /// Extract trace context from request headers.
  TenantTraceContext? extractFromHeaders(Map<String, String> headers) {
    final traceId = headers['X-Trace-ID'];
    final tenantId = headers['X-Tenant-ID'];
    final operation = headers['X-Operation'];
    final userId = headers['X-User-ID'];

    if (traceId == null || tenantId == null) return null;

    return TenantTraceContext(
      traceId: traceId,
      tenantId: tenantId,
      operation: operation ?? 'unknown',
      userId: userId,
      startTime: DateTime.now(),
    );
  }

  /// Inject trace context into request headers.
  Map<String, String> injectHeaders(TenantTraceContext context) {
    return {
      'X-Trace-ID': context.traceId,
      'X-Tenant-ID': context.tenantId,
      'X-Operation': context.operation,
      if (context.userId != null) 'X-User-ID': context.userId!,
    };
  }

  /// Create a child span from an existing trace context.
  TenantTraceContext createChildSpan({
    required TenantTraceContext parent,
    required String operation,
  }) {
    return TenantTraceContext(
      traceId: _generateTraceId(),
      parentTraceId: parent.traceId,
      tenantId: parent.tenantId,
      operation: operation,
      userId: parent.userId,
      startTime: DateTime.now(),
    );
  }

  String _generateTraceId() {
    return 'trace_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Tenant trace context — represents a single trace span.
class TenantTraceContext {
  const TenantTraceContext({
    required this.traceId,
    required this.tenantId,
    required this.operation,
    required this.startTime,
    this.parentTraceId,
    this.userId,
    this.endTime,
    this.status = 'pending',
  });

  final String traceId;
  final String tenantId;
  final String operation;
  final String? parentTraceId;
  final String? userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;

  TenantTraceContext complete({String status = 'completed'}) {
    return TenantTraceContext(
      traceId: traceId,
      tenantId: tenantId,
      operation: operation,
      parentTraceId: parentTraceId,
      userId: userId,
      startTime: startTime,
      endTime: DateTime.now(),
      status: status,
    );
  }

  Duration get duration {
    final end = endTime;
    if (end == null) return Duration.zero;
    return end.difference(startTime);
  }
}
