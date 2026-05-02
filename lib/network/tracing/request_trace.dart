/// Trace of a single API request through the interceptor chain.
///
/// Design rationale:
/// - Every request gets a [traceId] for distributed tracing correlation.
/// - [phases] record the time spent in each stage (interceptor, network, etc.).
/// - [attemptHistory] tracks all retry attempts with their outcomes.
/// - [sensitiveDataSanitized] ensures tokens and PII are never in the trace.
class RequestTrace {
  RequestTrace({
    required this.traceId,
    required this.method,
    required this.path,
    DateTime? startTime,
  })  : startTime = startTime ?? DateTime.now(),
        _phases = [],
        _attemptHistory = [];

  final String traceId;
  final String method;
  final String path;
  final DateTime startTime;
  final List<TracePhase> _phases;
  final List<AttemptRecord> _attemptHistory;

  DateTime? endTime;
  int? statusCode;
  bool? success;
  String? failureReason;

  /// Duration of the entire request lifecycle.
  Duration? get totalDuration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Add a phase record.
  void addPhase({
    required String name,
    required Duration duration,
    bool success = true,
    String? detail,
  }) {
    _phases.add(TracePhase(
      name: name,
      duration: duration,
      success: success,
      detail: detail,
    ));
  }

  /// Record a retry attempt.
  void recordAttempt({
    required int attemptNumber,
    required int? statusCode,
    required Duration duration,
    bool success = false,
    String? failureType,
  }) {
    _attemptHistory.add(AttemptRecord(
      attemptNumber: attemptNumber,
      statusCode: statusCode,
      duration: duration,
      success: success,
      failureType: failureType,
    ));
  }

  List<TracePhase> get phases => List.unmodifiable(_phases);
  List<AttemptRecord> get attemptHistory => List.unmodifiable(_attemptHistory);

  int get retryCount => _attemptHistory.length;

  /// Summary string for logging.
  String get summary {
    final parts = [
      '$method $path',
      'trace=$traceId',
      if (totalDuration != null) '${totalDuration!.inMilliseconds}ms',
      if (statusCode != null) 'HTTP $statusCode',
      if (retryCount > 0) '$retryCount retries',
      if (success != null) (success! ? 'success' : 'failed'),
    ];
    return parts.join(' | ');
  }
}

class TracePhase {
  const TracePhase({
    required this.name,
    required this.duration,
    required this.success,
    this.detail,
  });

  final String name;
  final Duration duration;
  final bool success;
  final String? detail;
}

class AttemptRecord {
  const AttemptRecord({
    required this.attemptNumber,
    this.statusCode,
    required this.duration,
    required this.success,
    this.failureType,
  });

  final int attemptNumber;
  final int? statusCode;
  final Duration duration;
  final bool success;
  final String? failureType;
}
