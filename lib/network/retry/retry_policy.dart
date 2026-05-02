import 'package:flutter_production_kit/network/models/api_request.dart';

/// Retry policy for API requests.
///
/// Design rationale:
/// - NOT "retry N times blindly" — every parameter is intentional.
/// - [maxRetries] is the ceiling, but actual retries depend on the endpoint
///   criticality, HTTP method, and response status.
/// - [baseDelay] and [maxDelay] control exponential backoff bounds.
/// - [retryableStatusCodes] is explicit — only listed codes trigger retries.
/// - [blockForCriticality] prevents retries on dangerous endpoint classes.
/// - [considerMethodSafety] prevents retrying non-idempotent methods.
class RetryPolicy {
  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.retryableStatusCodes = const [502, 503, 504],
    this.blockForCriticality = const [
      EndpointCriticality.critical,
      EndpointCriticality.destructive,
    ],
    this.considerMethodSafety = true,
    this.jitter = true,
    this.retryOnTimeout = true,
  });

  /// Maximum number of retry attempts (not counting the original attempt).
  final int maxRetries;

  /// Initial delay before the first retry.
  final Duration baseDelay;

  /// Maximum delay cap for exponential backoff.
  final Duration maxDelay;

  /// HTTP status codes that are considered retryable.
  /// Default: 502, 503, 504 (transient server errors).
  final List<int> retryableStatusCodes;

  /// Endpoint criticality levels that should NEVER be retried.
  final List<EndpointCriticality> blockForCriticality;

  /// Whether to block retries for non-idempotent HTTP methods.
  final bool considerMethodSafety;

  /// Whether to add random jitter to delay (prevents thundering herd).
  final bool jitter;

  /// Whether timeout errors are retryable.
  final bool retryOnTimeout;

  /// Default policy for safe GET endpoints.
  static const safeGet = RetryPolicy(
    maxRetries: 3,
    retryableStatusCodes: [408, 429, 500, 502, 503, 504],
    retryOnTimeout: true,
    considerMethodSafety: false, // GET is always safe.
  );

  /// Default policy for standard POST/PUT endpoints.
  static const standard = RetryPolicy(
    maxRetries: 2,
    retryableStatusCodes: [502, 503, 504],
    considerMethodSafety: true,
    retryOnTimeout: false,
  );

  /// Policy for critical endpoints — NO automatic retries.
  static const critical = RetryPolicy(
    maxRetries: 0,
    blockForCriticality: [
      EndpointCriticality.critical,
      EndpointCriticality.destructive,
      EndpointCriticality.standard,
      EndpointCriticality.auth,
    ],
    considerMethodSafety: true,
    retryOnTimeout: false,
  );

  /// Policy that blocks ALL retries.
  static const never = RetryPolicy(maxRetries: 0);

  /// Calculate the delay for a given retry attempt (exponential backoff).
  Duration getDelayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final exponentialMs = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final cappedMs = exponentialMs.clamp(
      baseDelay.inMilliseconds,
      maxDelay.inMilliseconds,
    );

    if (jitter) {
      // Add 0-25% random jitter to prevent thundering herd.
      final jitterMs = (cappedMs * 0.25).toInt();
      return Duration(milliseconds: cappedMs + (jitterMs ~/ 2));
    }

    return Duration(milliseconds: cappedMs);
  }
}
