/// Structured log entry — production-safe, correlation-aware log record.
///
/// Design rationale:
/// - [level] determines log priority and sampling behavior.
/// - [module] identifies the source component.
/// - [correlationId] links related logs across modules.
/// - [userId] is a safe identifier — NEVER PII.
/// - [action] describes the business operation.
/// - [message] is a human-readable description.
/// - [attributes] carries safe diagnostic context.
/// - [sensitiveFields] lists fields that were masked.
/// - [sampled] indicates if this log was sampled (high-volume safety).
///
/// Logging safety rules:
/// - NO tokens, passwords, card numbers, or PII.
/// - All sensitive fields are masked before logging.
/// - High-volume modules use sampling.
/// - Offline logs are buffered and flushed when connected.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.correlationId,
    this.userId,
    this.action,
    this.target,
    this.attributes = const {},
    this.sensitiveFields = const [],
    this.sampled = false,
    this.error,
    this.stackTrace,
  });

  final String id;
  final DateTime timestamp;
  final LogLevel level;
  final String module;
  final String message;
  final String? correlationId;
  final String? userId;
  final String? action;
  final String? target;
  final Map<String, String> attributes;
  final List<String> sensitiveFields;
  final bool sampled;
  final String? error;
  final String? stackTrace;

  bool get isCritical =>
      level == LogLevel.error || level == LogLevel.fatal;

  bool get isSampled => sampled;
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}
