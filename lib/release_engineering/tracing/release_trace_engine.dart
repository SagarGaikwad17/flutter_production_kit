/// Release trace engine — distributed tracing for release/deployment operations.
///
/// Design rationale:
/// - Propagates trace IDs across release pipeline stages.
/// - Creates trace spans for build, validate, sign, approve, deploy, rollout.
/// - Integrates with observability tracing layer.
/// - Supports trace context extraction/injection for CI/CD systems.
/// - Secret-safe — no sensitive data in trace metadata.
///
/// Trace spans:
/// - Build pipeline execution.
/// - Flavor validation.
/// - Artifact signing.
/// - Approval workflow.
/// - Environment validation.
/// - Rollout execution.
/// - Rollback execution.
/// - Compliance checks.
class ReleaseTraceEngine {
  const ReleaseTraceEngine();

  /// Create a new trace context for a release operation.
  ReleaseTraceContext createTraceContext({
    required String releaseId,
    required String operation,
    String? parentTraceId,
    String? environment,
    String? triggeredBy,
  }) {
    return ReleaseTraceContext(
      traceId: _generateTraceId(),
      releaseId: releaseId,
      operation: operation,
      parentTraceId: parentTraceId,
      environment: environment,
      triggeredBy: triggeredBy,
      startTime: DateTime.now(),
    );
  }

  /// Extract trace context from CI/CD headers.
  ReleaseTraceContext? extractFromHeaders(Map<String, String> headers) {
    final traceId = headers['X-Release-Trace-ID'];
    final releaseId = headers['X-Release-ID'];
    final operation = headers['X-Release-Operation'];
    final environment = headers['X-Release-Environment'];
    final triggeredBy = headers['X-Release-Triggered-By'];

    if (traceId == null || releaseId == null) return null;

    return ReleaseTraceContext(
      traceId: traceId,
      releaseId: releaseId,
      operation: operation ?? 'unknown',
      environment: environment,
      triggeredBy: triggeredBy,
      startTime: DateTime.now(),
    );
  }

  /// Inject trace context into CI/CD headers.
  Map<String, String> injectHeaders(ReleaseTraceContext context) {
    return {
      'X-Release-Trace-ID': context.traceId,
      'X-Release-ID': context.releaseId,
      'X-Release-Operation': context.operation,
      if (context.environment != null) 'X-Release-Environment': context.environment!,
      if (context.triggeredBy != null) 'X-Release-Triggered-By': context.triggeredBy!,
    };
  }

  /// Create a child span from an existing trace context.
  ReleaseTraceContext createChildSpan({
    required ReleaseTraceContext parent,
    required String operation,
  }) {
    return ReleaseTraceContext(
      traceId: _generateTraceId(),
      releaseId: parent.releaseId,
      operation: operation,
      parentTraceId: parent.traceId,
      environment: parent.environment,
      triggeredBy: parent.triggeredBy,
      startTime: DateTime.now(),
    );
  }

  String _generateTraceId() {
    return 'rel_trace_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Release trace context — represents a single trace span.
class ReleaseTraceContext {
  const ReleaseTraceContext({
    required this.traceId,
    required this.releaseId,
    required this.operation,
    required this.startTime,
    this.parentTraceId,
    this.environment,
    this.triggeredBy,
    this.endTime,
    this.status = 'pending',
  });

  final String traceId;
  final String releaseId;
  final String operation;
  final String? parentTraceId;
  final String? environment;
  final String? triggeredBy;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;

  ReleaseTraceContext complete({String status = 'completed'}) {
    return ReleaseTraceContext(
      traceId: traceId,
      releaseId: releaseId,
      operation: operation,
      parentTraceId: parentTraceId,
      environment: environment,
      triggeredBy: triggeredBy,
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
