import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';

/// Classifies HTTP errors and network exceptions into typed [ApiFailure] objects.
///
/// Design rationale:
/// - The classifier is the single point where raw errors become structured failures.
/// - It considers endpoint criticality when classifying — a 500 on a payment
///   endpoint is classified differently from a 500 on a feed endpoint.
/// - Response body parsing extracts error messages without logging sensitive data.
/// - Headers (X-RateLimit, X-Maintenance) are inspected for context.
class FailureClassifier {
  FailureClassifier({
    this.maintenanceModeHeader = 'X-Maintenance-Mode',
    this.retryAfterHeader = 'Retry-After',
    this.traceIdHeader = 'X-Trace-Id',
    this.updateRequiredHeader = 'X-Update-Required',
  });

  static const String _tag = 'FailureClassifier';

  final String maintenanceModeHeader;
  final String retryAfterHeader;
  final String traceIdHeader;
  final String updateRequiredHeader;

  /// Classify an HTTP response error into a typed [ApiFailure].
  ApiFailure classifyResponse({
    required http.Response response,
    required ApiRequestContext request,
    Object? cause,
  }) {
    final traceId = response.headers[traceIdHeader.toLowerCase()];
    final statusCode = response.statusCode;

    // Check for forced update requirement.
    final updateRequired = response.headers[updateRequiredHeader.toLowerCase()];
    if (updateRequired != null && updateRequired == 'true') {
      return ApiUpdateRequiredFailure(
        message: 'Backend requires app update.',
        statusCode: statusCode,
        traceId: traceId,
        minimumVersion: response.headers['x-minimum-version'],
      );
    }

    // Check for maintenance mode.
    final isMaintenance = response.headers[maintenanceModeHeader.toLowerCase()] == 'true';

    // Check for rate limiting.
    if (statusCode == 429) {
      final retryAfterSec = int.tryParse(response.headers[retryAfterHeader.toLowerCase()] ?? '');
      return ApiRateLimitFailure(
        message: _extractErrorMessage(response),
        statusCode: statusCode,
        traceId: traceId,
        retryAfter: retryAfterSec != null ? Duration(seconds: retryAfterSec) : null,
        limitType: response.headers['x-ratelimit-type'],
      );
    }

    // Auth failures (401, 403).
    if (statusCode == 401 || statusCode == 403) {
      final body = _extractErrorMessage(response).toLowerCase();
      final isRevoked = body.contains('revoked') ||
          body.contains('invalidated') ||
          body.contains('disabled');

      return ApiAuthFailure(
        message: _extractErrorMessage(response),
        statusCode: statusCode,
        traceId: traceId,
        requiresRefresh: statusCode == 401,
        sessionRevoked: isRevoked,
      );
    }

    // Validation errors (422).
    if (statusCode == 422) {
      return ApiValidationFailure(
        message: _extractErrorMessage(response),
        statusCode: statusCode,
        traceId: traceId,
        fieldErrors: _extractFieldErrors(response),
      );
    }

    // Client errors (4xx).
    if (statusCode >= 400 && statusCode < 500) {
      return ApiClientFailure(
        message: _extractErrorMessage(response),
        statusCode: statusCode,
        traceId: traceId,
        cause: cause,
      );
    }

    // Server errors (5xx).
    if (statusCode >= 500) {
      final isRetryable = _isServerFailureRetryable(
        statusCode: statusCode,
        request: request,
      );

      return ApiServerFailure(
        message: _extractErrorMessage(response),
        statusCode: statusCode,
        traceId: traceId,
        cause: cause,
        retryable: isRetryable,
        isMaintenanceMode: isMaintenance,
      );
    }

    return GenericApiFailure(
      message: 'Unexpected HTTP status: $statusCode',
      statusCode: statusCode,
      traceId: traceId,
      cause: cause,
    );
  }

  /// Classify a network exception (timeout, DNS failure, etc.).
  ApiFailure classifyException({
    required Object exception,
    required ApiRequestContext request,
    String? traceId,
  }) {
    final e = exception;

    if (e is http.ClientException) {
      final message = e.message.toLowerCase();
      if (message.contains('timeout') || message.contains('timed out')) {
        return ApiTimeoutFailure(
          message: 'Request timed out.',
          traceId: traceId,
          cause: e,
          timeoutDuration: request.timeout,
        );
      }

      if (message.contains('connection') ||
          message.contains('network') ||
          message.contains('refused') ||
          message.contains('unreachable')) {
        return const ApiNetworkUnavailableFailure(
          message: 'Network connection unavailable.',
        );
      }

      return ApiNetworkUnavailableFailure(
        message: 'HTTP client error: ${e.message}',
        cause: e,
      );
    }

    if (e is ApiFailure) {
      return e;
    }

    return GenericApiFailure(
      message: 'Unexpected network error: $e',
      traceId: traceId,
      cause: e,
    );
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  bool _isServerFailureRetryable({
    required int statusCode,
    required ApiRequestContext request,
  }) {
    // Critical endpoints are NEVER retryable on server error.
    if (request.criticality == EndpointCriticality.critical) {
      return false;
    }

    // Destructive endpoints are NEVER retryable.
    if (request.criticality == EndpointCriticality.destructive) {
      return false;
    }

    // Non-idempotent methods (POST) are not retried for server errors
    // unless explicitly marked safe.
    if (!request.method.isIdempotent && request.criticality == EndpointCriticality.standard) {
      return false;
    }

    // 502/503/504 are typically transient — safe to retry for GET/PUT.
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return request.method.isSafe;
    }

    // 500 is ambiguous — only retry for safe endpoints.
    if (statusCode == 500) {
      return request.method.isSafe;
    }

    return false;
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = response.body;
      if (body.isEmpty) return 'No error details provided.';

      // Try to extract from JSON error response.
      if (body.startsWith('{')) {
        final json = _tryParseJson(body);
        if (json != null) {
          return json['message'] as String? ??
              json['error'] as String? ??
              json['detail'] as String? ??
              'Server error occurred.';
        }
      }

      // Truncate long bodies — never log full response in failure classification.
      return body.length > 200 ? '${body.substring(0, 200)}...' : body;
    } catch (e) {
      return 'Server error occurred.';
    }
  }

  Map<String, String> _extractFieldErrors(http.Response response) {
    try {
      final body = response.body;
      if (body.startsWith('{')) {
        final json = _tryParseJson(body);
        if (json != null) {
          final errors = json['errors'];
          if (errors is Map) {
            return errors.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
          if (errors is List) {
            return {
              for (final error in errors)
                error.toString(): error.toString(),
            };
          }
        }
      }
    } catch (_) {}
    return {};
  }

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      return const JsonDecoder().convert(raw);
    } catch (_) {
      return null;
    }
  }
}
