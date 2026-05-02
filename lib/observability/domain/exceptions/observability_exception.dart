/// Observability exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific observability failure mode.
/// - [ObservabilityException] is the base for all observability errors.
/// - [AuditException] covers audit trail failures.
/// - [TraceException] covers tracing failures.
/// - [SecurityException] covers security event failures.
/// - [RetentionException] covers retention policy failures.
/// - NO sensitive data in exception messages.
sealed class ObservabilityException implements Exception {
  const ObservabilityException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'ObservabilityException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Audit entry could not be recorded.
final class AuditRecordingFailedException extends ObservabilityException {
  const AuditRecordingFailedException({
    required super.message,
    super.cause,
    this.entryId,
    this.module,
  });
  final String? entryId;
  final String? module;
}

/// Audit entry tampering detected.
final class AuditTamperingDetectedException extends ObservabilityException {
  const AuditTamperingDetectedException({
    required super.message,
    this.entryId,
    this.expectedVersion,
    this.foundVersion,
  });
  final String? entryId;
  final int? expectedVersion;
  final int? foundVersion;
}

/// Trace could not be created.
final class TraceCreationFailedException extends ObservabilityException {
  const TraceCreationFailedException({
    required super.message,
    super.cause,
    this.traceId,
    this.operation,
  });
  final String? traceId;
  final String? operation;
}

/// Trace span could not be completed.
final class TraceSpanCompletionFailedException extends ObservabilityException {
  const TraceSpanCompletionFailedException({
    required super.message,
    this.spanId,
    this.traceId,
  });
  final String? spanId;
  final String? traceId;
}

/// Correlation ID missing for cross-module trace.
final class CorrelationIdMissingException extends ObservabilityException {
  const CorrelationIdMissingException({
    required super.message,
    this.module,
    this.operation,
  });
  final String? module;
  final String? operation;
}

/// Security event could not be recorded.
final class SecurityEventRecordingFailedException extends ObservabilityException {
  const SecurityEventRecordingFailedException({
    required super.message,
    super.cause,
    this.eventType,
    this.severity,
  });
  final String? eventType;
  final String? severity;
}

/// Retention policy violation.
final class RetentionPolicyViolationException extends ObservabilityException {
  const RetentionPolicyViolationException({
    required super.message,
    this.category,
    this.entryId,
  });
  final String? category;
  final String? entryId;
}

/// Privacy violation detected — sensitive data in log.
final class PrivacyViolationException extends ObservabilityException {
  const PrivacyViolationException({
    required super.message,
    this.fieldName,
    this.module,
  });
  final String? fieldName;
  final String? module;
}
