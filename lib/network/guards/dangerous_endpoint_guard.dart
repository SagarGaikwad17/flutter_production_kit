import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';

/// Guard that protects dangerous endpoints from unsafe operations.
///
/// Design rationale:
/// - Some endpoints MUST NOT be retried, deduplicated, or cached.
/// - This guard enforces those rules at the interceptor level.
/// - Payment endpoints require an idempotency key — requests without one are blocked.
/// - Destructive endpoints (delete, revoke) cannot be retried.
/// - The guard logs all blocked attempts for security auditing.
class DangerousEndpointGuard {
  DangerousEndpointGuard({
    List<String>? paymentPaths,
    List<String>? destructivePaths,
    List<String>? nonRetryablePaths,
  })  : _paymentPaths = paymentPaths ?? _defaultPaymentPaths,
        _destructivePaths = destructivePaths ?? _defaultDestructivePaths,
        _nonRetryablePaths = nonRetryablePaths ?? _defaultNonRetryablePaths;

  static const String _tag = 'DangerousEndpointGuard';

  final List<String> _paymentPaths;
  final List<String> _destructivePaths;
  final List<String> _nonRetryablePaths;

  static const _defaultPaymentPaths = [
    '/payments',
    '/charges',
    '/subscriptions',
    '/billing',
    '/checkout',
    '/transactions',
    '/purchases',
  ];

  static const _defaultDestructivePaths = [
    '/sessions/revoke',
    '/devices/remove',
    '/accounts/delete',
    '/users/ban',
    '/data/purge',
  ];

  static const _defaultNonRetryablePaths = [
    '/password/reset',
    '/email/verify',
    '/otp/send',
    '/logout',
  ];

  /// Validate a request before execution.
  ///
  /// Returns null if the request is safe to execute.
  /// Returns [ApiBlockedFailure] if the request violates a safety rule.
  ApiBlockedFailure? validate(ApiRequestContext request) {
    final path = request.path.toLowerCase();

    // Payment endpoints MUST have an idempotency key.
    if (_matchesAny(path, _paymentPaths) && request.method != HttpMethod.get) {
      if (request.idempotencyKey == null || request.idempotencyKey!.isEmpty) {
        AppLogger.warning(
          _tag,
          'BLOCKED: Payment endpoint without idempotency key: ${request.path}',
        );
        return ApiBlockedFailure(
          message: 'Payment endpoints require an idempotency key.',
          traceId: request.traceId,
          blockReason: 'payment_endpoint_requires_idempotency_key',
        );
      }
    }

    // Destructive endpoints must use POST/DELETE only — prevent accidental GET/PUT.
    if (_matchesAny(path, _destructivePaths)) {
      if (request.method == HttpMethod.get) {
        AppLogger.warning(
          _tag,
          'BLOCKED: GET request to destructive endpoint: ${request.path}',
        );
        return ApiBlockedFailure(
          message: 'GET not allowed on destructive endpoints.',
          traceId: request.traceId,
          blockReason: 'get_on_destructive_endpoint',
        );
      }
    }

    return null;
  }

  /// Whether the request path matches a dangerous pattern.
  bool isDangerous(ApiRequestContext request) {
    final path = request.path.toLowerCase();
    return _matchesAny(path, _paymentPaths) ||
        _matchesAny(path, _destructivePaths);
  }

  /// Whether the endpoint should not be retried.
  bool isNonRetryable(ApiRequestContext request) {
    final path = request.path.toLowerCase();
    return _matchesAny(path, _nonRetryablePaths) ||
        request.criticality == EndpointCriticality.critical ||
        request.criticality == EndpointCriticality.destructive;
  }

  /// Whether the endpoint should not be cached.
  bool isNonCacheable(ApiRequestContext request) {
    return request.method != HttpMethod.get || isDangerous(request);
  }

  /// Whether the endpoint should be deduplicated (yes for all).
  bool shouldDeduplicate(ApiRequestContext request) {
    return true;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _matchesAny(String path, List<String> patterns) {
    return patterns.any((pattern) {
      final lowerPattern = pattern.toLowerCase();
      return path == lowerPattern ||
          path.startsWith('$lowerPattern/') ||
          path.contains(lowerPattern);
    });
  }
}
