import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/retry/retry_policy.dart';

/// Retry decision engine — determines whether a failed request should be retried.
///
/// Design rationale:
/// - The engine makes the final retry decision by considering:
///   1. Endpoint criticality (critical = never retry).
///   2. HTTP method safety (POST = careful, GET = safe).
///   3. Response status code (only specific codes are retryable).
///   4. Failure type (timeout = maybe, auth = never, blocked = never).
///   5. Per-request overrides (blockRetry flag).
///   6. Attempt count (don't exceed maxRetries).
///
/// This is NOT "retry 3 times for everything." Each failure is evaluated
/// against the policy to determine if retrying is safe AND appropriate.
class RetryEngine {
  RetryEngine({
    RetryPolicy? defaultPolicy,
  }) : _defaultPolicy = defaultPolicy ?? RetryPolicy.standard;

  static const String _tag = 'RetryEngine';

  final RetryPolicy _defaultPolicy;

  /// Evaluate whether a failed request should be retried.
  ///
  /// Returns a [RetryDecision] with the action and reasoning.
  RetryDecision evaluate({
    required ApiRequestContext request,
    required ApiFailure failure,
    required int attemptNumber,
    RetryPolicy? policy,
  }) {
    final effectivePolicy = policy ?? _defaultPolicy;

    // Check per-request override.
    if (request.retryOverride?.blockRetry == true) {
      return RetryDecision.noRetry(
        reason: 'Retry blocked by request override.',
        failure: failure,
      );
    }

    // Criticality check — some endpoints should NEVER be retried.
    if (effectivePolicy.blockForCriticality.contains(request.criticality)) {
      AppLogger.warning(
        _tag,
        'Retry blocked: endpoint criticality "${request.criticality.name}" '
        'does not allow retries. Path: ${request.path}',
      );
      return RetryDecision.noRetry(
        reason: 'Endpoint criticality "${request.criticality.name}" blocks retries.',
        failure: failure,
      );
    }

    // Method safety check — non-idempotent methods are risky.
    if (effectivePolicy.considerMethodSafety && !request.method.isIdempotent) {
      AppLogger.warning(
        _tag,
        'Retry blocked: non-idempotent method ${request.method.value} '
        'on path: ${request.path}',
      );
      return RetryDecision.noRetry(
        reason: 'Non-idempotent method ${request.method.value} blocks retries.',
        failure: failure,
      );
    }

    // Attempt count check.
    if (attemptNumber >= effectivePolicy.maxRetries) {
      return RetryDecision.noRetry(
        reason: 'Max retries (${effectivePolicy.maxRetries}) exhausted.',
        failure: failure,
      );
    }

    // Evaluate failure type for retry eligibility.
    return switch (failure) {
      ApiAuthFailure() =>
        RetryDecision.noRetry(
          reason: 'Auth failure — retry will not help. Token refresh required.',
          failure: failure,
        ),
      ApiBlockedFailure() =>
        RetryDecision.noRetry(
          reason: 'Request was blocked by safety guard.',
          failure: failure,
        ),
      ApiDuplicateRequestFailure() =>
        RetryDecision.noRetry(
          reason: 'Duplicate request blocked.',
          failure: failure,
        ),
      ApiRetryBlockedFailure() =>
        RetryDecision.noRetry(
          reason: 'Retry was blocked by policy.',
          failure: failure,
        ),
      ApiCacheInvalidatedFailure() =>
        RetryDecision.noRetry(
          reason: 'Cache invalidated — retry will repeat the same failure.',
          failure: failure,
        ),
      ApiUpdateRequiredFailure() =>
        RetryDecision.noRetry(
          reason: 'App update required — retry will not help.',
          failure: failure,
        ),
      ApiCancelledFailure() =>
        RetryDecision.noRetry(
          reason: 'Request was cancelled.',
          failure: failure,
        ),
      ApiValidationFailure() =>
        RetryDecision.noRetry(
          reason: 'Validation failure — retrying with same data will not help.',
          failure: failure,
        ),
      ApiNetworkUnavailableFailure() =>
        _evaluateNetworkRetry(
          request: request,
          failure: failure,
          attemptNumber: attemptNumber,
          policy: effectivePolicy,
        ),
      ApiTimeoutFailure() =>
        _evaluateTimeoutRetry(
          request: request,
          failure: failure,
          attemptNumber: attemptNumber,
          policy: effectivePolicy,
        ),
      ApiRateLimitFailure(:final retryAfter) =>
        _evaluateRateLimitRetry(
          request: request,
          failure: failure,
          attemptNumber: attemptNumber,
          policy: effectivePolicy,
          retryAfter: retryAfter,
        ),
      ApiServerFailure(:final retryable, :final statusCode) =>
        _evaluateServerRetry(
          request: request,
          failure: failure,
          attemptNumber: attemptNumber,
          policy: effectivePolicy,
          retryable: retryable,
          statusCode: statusCode ?? 500,
        ),
      _ =>
        RetryDecision.noRetry(
          reason: 'Failure type not classified as retryable.',
          failure: failure,
        ),
    };
  }

  RetryDecision _evaluateNetworkRetry({
    required ApiRequestContext request,
    required ApiNetworkUnavailableFailure failure,
    required int attemptNumber,
    required RetryPolicy policy,
  }) {
    // Network unavailable — retry only if endpoint is safe.
    if (request.method.isSafe) {
      final delay = policy.getDelayForAttempt(attemptNumber + 1);
      AppLogger.info(
        _tag,
        'Network retry scheduled for ${request.path} '
        '(attempt ${attemptNumber + 1}/${policy.maxRetries}, delay: ${delay.inMilliseconds}ms)',
      );
      return RetryDecision.retry(delay: delay, failure: failure);
    }

    return RetryDecision.noRetry(
      reason: 'Network unavailable — write endpoint not retried.',
      failure: failure,
    );
  }

  RetryDecision _evaluateTimeoutRetry({
    required ApiRequestContext request,
    required ApiTimeoutFailure failure,
    required int attemptNumber,
    required RetryPolicy policy,
  }) {
    if (!policy.retryOnTimeout) {
      return RetryDecision.noRetry(
        reason: 'Timeout retries disabled by policy.',
        failure: failure,
      );
    }

    if (request.criticality == EndpointCriticality.critical) {
      return RetryDecision.noRetry(
        reason: 'Critical endpoint — timeout not retried.',
        failure: failure,
      );
    }

    final delay = policy.getDelayForAttempt(attemptNumber + 1);
    return RetryDecision.retry(delay: delay, failure: failure);
  }

  RetryDecision _evaluateRateLimitRetry({
    required ApiRequestContext request,
    required ApiRateLimitFailure failure,
    required int attemptNumber,
    required RetryPolicy policy,
    Duration? retryAfter,
  }) {
    // Respect server's Retry-After header if available.
    final delay = retryAfter ?? policy.getDelayForAttempt(attemptNumber + 1);

    if (delay > const Duration(minutes: 5)) {
      return RetryDecision.noRetry(
        reason: 'Rate limit retry-after too long (${delay.inMinutes}min).',
        failure: failure,
      );
    }

    AppLogger.info(
      _tag,
      'Rate limit retry for ${request.path} '
      '(attempt ${attemptNumber + 1}, delay: ${delay.inMilliseconds}ms)',
    );
    return RetryDecision.retry(delay: delay, failure: failure);
  }

  RetryDecision _evaluateServerRetry({
    required ApiRequestContext request,
    required ApiServerFailure failure,
    required int attemptNumber,
    required RetryPolicy policy,
    required bool retryable,
    required int statusCode,
  }) {
    if (!retryable) {
      return RetryDecision.noRetry(
        reason: 'Server failure not classified as retryable (status: $statusCode).',
        failure: failure,
      );
    }

    if (!policy.retryableStatusCodes.contains(statusCode)) {
      return RetryDecision.noRetry(
        reason: 'Status code $statusCode not in retryable list.',
        failure: failure,
      );
    }

    final delay = policy.getDelayForAttempt(attemptNumber + 1);
    AppLogger.info(
      _tag,
      'Server retry for ${request.path} '
      '(attempt ${attemptNumber + 1}/${policy.maxRetries}, '
      'status: $statusCode, delay: ${delay.inMilliseconds}ms)',
    );
    return RetryDecision.retry(delay: delay, failure: failure);
  }
}

/// Result of retry engine evaluation.
sealed class RetryDecision {
  const RetryDecision();

  static RetryDecision retry({required Duration delay, required ApiFailure failure}) =>
      RetryDecisionRetry(delay: delay, failure: failure);

  static RetryDecision noRetry({required String reason, required ApiFailure failure}) =>
      RetryDecisionNoRetry(reason: reason, failure: failure);
}

final class RetryDecisionRetry extends RetryDecision {
  const RetryDecisionRetry({required this.delay, required this.failure});

  final Duration delay;
  final ApiFailure failure;

  @override
  String toString() => 'Retry(delay: ${delay.inMilliseconds}ms)';
}

final class RetryDecisionNoRetry extends RetryDecision {
  const RetryDecisionNoRetry({required this.reason, required this.failure});

  final String reason;
  final ApiFailure failure;

  @override
  String toString() => 'NoRetry(reason: $reason)';
}
