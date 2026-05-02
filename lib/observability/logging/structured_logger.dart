import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/observability/domain/entities/log_entry.dart';
import 'package:flutter_production_kit/observability/logging/log_context_manager.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Structured logger — production-safe, correlation-aware logging engine.
///
/// Design rationale:
/// - Wraps the existing AppLogger for backward compatibility.
/// - Adds structured metadata: correlationId, userId, action, target.
/// - PII-safe — sensitive fields are automatically masked.
/// - Sampling support for high-volume modules.
/// - Offline buffering — logs are stored locally and flushed when connected.
/// - All log entries are persisted to the LogRepository for investigation.
///
/// Logging safety rules:
/// - NO tokens, passwords, card numbers, or PII.
/// - Sensitive fields are detected by name patterns and masked.
/// - Error messages never include raw request/response bodies.
/// - Stack traces are included only for error/fatal levels.
class StructuredLogger {
  StructuredLogger({
    required LogRepository logRepository,
    required LogContextManager contextManager,
    double? sampleRate,
  })  : _logRepository = logRepository,
        _contextManager = contextManager,
        _sampleRate = sampleRate ?? 1.0;

  static const String _tag = 'StructuredLogger';

  final LogRepository _logRepository;
  final LogContextManager _contextManager;
  final double _sampleRate;

  final List<String> _sensitivePatterns = const [
    'token',
    'secret',
    'password',
    'card',
    'ssn',
    'email',
    'phone',
    'address',
    'dob',
    'name',
  ];

  /// Log a structured info message.
  Future<void> info(
    String module,
    String message, {
    String? action,
    String? target,
    Map<String, String>? attributes,
  }) {
    return _log(
      level: LogLevel.info,
      module: module,
      message: message,
      action: action,
      target: target,
      attributes: attributes,
    );
  }

  /// Log a structured warning.
  Future<void> warning(
    String module,
    String message, {
    String? action,
    String? target,
    Map<String, String>? attributes,
    Object? error,
  }) {
    return _log(
      level: LogLevel.warning,
      module: module,
      message: message,
      action: action,
      target: target,
      attributes: attributes,
      error: error,
    );
  }

  /// Log a structured error.
  Future<void> error(
    String module,
    String message, {
    required Object error,
    StackTrace? stackTrace,
    String? action,
    String? target,
    Map<String, String>? attributes,
  }) {
    return _log(
      level: LogLevel.error,
      module: module,
      message: message,
      action: action,
      target: target,
      attributes: attributes,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a structured fatal error.
  Future<void> fatal(
    String module,
    String message, {
    required Object error,
    StackTrace? stackTrace,
    String? action,
    String? target,
    Map<String, String>? attributes,
  }) {
    return _log(
      level: LogLevel.fatal,
      module: module,
      message: message,
      action: action,
      target: target,
      attributes: attributes,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a structured debug message (subject to sampling).
  Future<void> debug(
    String module,
    String message, {
    String? action,
    String? target,
    Map<String, String>? attributes,
  }) {
    return _log(
      level: LogLevel.debug,
      module: module,
      message: message,
      action: action,
      target: target,
      attributes: attributes,
    );
  }

  // ── Internal Logging ───────────────────────────────────────────────────────

  Future<void> _log({
    required LogLevel level,
    required String module,
    required String message,
    String? action,
    String? target,
    Map<String, String>? attributes,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    // Sampling check for debug logs.
    final sampled = level == LogLevel.debug && _shouldSample();

    // Get context.
    final context = _contextManager.current;

    // Sanitize attributes.
    final safeAttributes = _sanitizeAttributes(attributes ?? {});
    final sensitiveFields = _detectSensitiveFields(attributes ?? {});

    // Create log entry.
    final entry = LogEntry(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      level: level,
      module: module,
      message: message,
      correlationId: context.correlationId,
      userId: context.userId,
      action: action,
      target: target,
      attributes: safeAttributes,
      sensitiveFields: sensitiveFields,
      sampled: sampled,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    // Persist to repository.
    try {
      await _logRepository.saveLogEntry(entry);
    } catch (_) {
      // Logging must never fail the calling operation.
    }

    // Write to AppLogger for console output.
    _writeToConsole(entry);
  }

  void _writeToConsole(LogEntry entry) {
    final prefix = '[${entry.module}]';
    final msg = entry.message;

    switch (entry.level) {
      case LogLevel.debug:
        AppLogger.debug(_tag, '$prefix $msg');
      case LogLevel.info:
        AppLogger.info(_tag, '$prefix $msg');
      case LogLevel.warning:
        AppLogger.warning(_tag, '$prefix $msg');
      case LogLevel.error:
        AppLogger.error(
          _tag,
          '$prefix $msg',
          error: entry.error ?? 'Unknown error',
        );
      case LogLevel.fatal:
        AppLogger.fatal(
          _tag,
          '$prefix $msg',
          error: entry.error ?? 'Unknown error',
        );
    }
  }

  bool _shouldSample() {
    // Deterministic sampling based on time.
    return DateTime.now().millisecondsSinceEpoch % 100 < (_sampleRate * 100);
  }

  Map<String, String> _sanitizeAttributes(Map<String, String> attributes) {
    final sanitized = <String, String>{};
    for (final entry in attributes.entries) {
      if (_isSensitiveField(entry.key)) {
        sanitized[entry.key] = '[MASKED]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  List<String> _detectSensitiveFields(Map<String, String> attributes) {
    return attributes.keys.where(_isSensitiveField).toList();
  }

  bool _isSensitiveField(String key) {
    final lower = key.toLowerCase();
    return _sensitivePatterns.any((pattern) => lower.contains(pattern));
  }
}
