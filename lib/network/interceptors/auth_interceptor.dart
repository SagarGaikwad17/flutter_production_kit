import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/auth/session/token_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Auth interceptor — injects the access token into requests.
///
/// Design rationale:
/// - Gets a valid token from [TokenManager] (handles refresh transparently).
/// - If token refresh fails during request, the request is cancelled and
///   an [ApiAuthFailure] is returned.
/// - Token is NEVER logged or included in traces.
/// - The interceptor is idempotent — safe to run on retry.
class AuthInterceptor {
  AuthInterceptor({
    required TokenManager tokenManager,
  }) : _tokenManager = tokenManager;

  static const String _tag = 'AuthInterceptor';

  final TokenManager _tokenManager;

  /// Apply auth headers to the request.
  ///
  /// Returns the modified request or an [ApiFailure] if auth is unavailable.
  Future<http.Request> apply({
    required http.Request request,
    required ApiRequestContext context,
    required RequestTrace trace,
  }) async {
    // Auth endpoints don't need a token.
    if (context.criticality == EndpointCriticality.auth) {
      return request;
    }

    try {
      final token = await _tokenManager.getValidAccessToken();
      request.headers['Authorization'] = 'Bearer $token';
      trace.addPhase(
        name: 'auth_interceptor',
        duration: Duration.zero,
        success: true,
        detail: 'token_injected',
      );
    } on ApiFailure catch (e) {
      AppLogger.warning(_tag, 'Auth interceptor: token unavailable', error: e);
      throw ApiAuthFailure(
        message: 'Authentication token unavailable.',
        statusCode: 401,
        traceId: trace.traceId,
        requiresRefresh: true,
        cause: e,
      );
    } catch (e) {
      AppLogger.error(_tag, 'Auth interceptor: unexpected error', error: e);
      throw ApiAuthFailure(
        message: 'Failed to obtain authentication token.',
        statusCode: 401,
        traceId: trace.traceId,
        cause: e,
      );
    }

    return request;
  }
}
