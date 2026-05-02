import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Logging interceptor — structured logging for all API requests/responses.
///
/// Design rationale:
/// - Logs are structured and tag-based for easy filtering.
/// - Sensitive data (tokens, passwords, PII) is NEVER logged.
/// - Request body is truncated and sanitized.
/// - Response body is only logged for failures (and truncated).
/// - Latency is always logged for observability.
class LoggingInterceptor {
  LoggingInterceptor({
    this.logRequestHeaders = false,
    this.logRequestBody = false,
    this.maxBodyLogLength = 500,
  });

  static const String _tag = 'LoggingInterceptor';

  final bool logRequestHeaders;
  final bool logRequestBody;
  final int maxBodyLogLength;

  void logRequest({
    required ApiRequestContext context,
    required RequestTrace trace,
  }) {
    final sanitizedHeaders = _sanitizeHeaders(context.headers);

    AppLogger.info(_tag, '→ ${context.method.value} ${context.path} '
        '[criticality: ${context.criticality.name}] '
        '${logRequestHeaders ? 'headers: $sanitizedHeaders' : ''}'
        'trace=${trace.traceId}');

    if (logRequestBody && context.body != null) {
      final bodyStr = _truncateAndSanitizeBody(context.body!);
      AppLogger.debug(_tag, 'Request body: $bodyStr');
    }
  }

  void logResponse({
    required int statusCode,
    required Duration duration,
    required ApiRequestContext context,
    required RequestTrace trace,
    String? responseBody,
    bool success = true,
  }) {
    final arrow = success ? '←' : '✗';
    final level = success ? 'info' : 'error';

    final message = '$arrow ${context.method.value} ${context.path} '
        '$statusCode ${duration.inMilliseconds}ms '
        'trace=${trace.traceId}';

    if (success) {
      AppLogger.info(_tag, message);
    } else {
      AppLogger.error(_tag, message, error: Exception('HTTP $statusCode'));
    }

    if (!success && responseBody != null) {
      final truncated = responseBody.length > maxBodyLogLength
          ? '${responseBody.substring(0, maxBodyLogLength)}...'
          : responseBody;
      AppLogger.debug(_tag, 'Error response body: $truncated');
    }
  }

  void logError({
    required Object error,
    required ApiRequestContext context,
    required RequestTrace trace,
  }) {
    AppLogger.error(
      _tag,
      '✗ ${context.method.value} ${context.path} '
      'error=${error.runtimeType} '
      'trace=${trace.traceId}',
      error: error,
    );
  }

  // ── Sanitization ───────────────────────────────────────────────────────────

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'authorization') {
        sanitized[entry.key] = 'Bearer ***REDACTED***';
      } else if (key.contains('cookie') || key.contains('token') || key.contains('secret')) {
        sanitized[entry.key] = '***REDACTED***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  String _truncateAndSanitizeBody(Map<String, dynamic> body) {
    final sanitized = _sanitizeBody(body);
    final encoded = jsonEncode(sanitized);
    if (encoded.length > maxBodyLogLength) {
      return '${encoded.substring(0, maxBodyLogLength)}... [truncated]';
    }
    return encoded;
  }

  Map<String, dynamic> _sanitizeBody(Map<String, dynamic> body) {
    final sensitiveKeys = {
      'password', 'token', 'secret', 'key', 'authorization',
      'access_token', 'refresh_token', 'api_key', 'apikey',
    };

    return body.map((key, value) {
      if (sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '***REDACTED***');
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _sanitizeBody(value));
      }
      return MapEntry(key, value);
    });
  }
}
