/// Retry backoff policy — controls how failed operations are retried.
///
/// Design rationale:
/// - Exponential backoff prevents server overload during outages.
/// - Jitter prevents thundering herd when many clients reconnect.
/// - Max retries prevent infinite retry loops.
/// - Retry classification determines which failures get retried.
/// - Network-specific backoff is more aggressive than server errors.
class RetryBackoffPolicy {
  const RetryBackoffPolicy({
    this.initialDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 30),
    this.maxRetries = 5,
    this.backoffMultiplier = 2.0,
    this.jitterFactor = 0.3,
    this.networkErrorDelay = const Duration(seconds: 2),
    this.serverErrorDelay = const Duration(seconds: 10),
    this.rateLimitDelay = const Duration(minutes: 5),
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final int maxRetries;
  final double backoffMultiplier;
  final double jitterFactor;
  final Duration networkErrorDelay;
  final Duration serverErrorDelay;
  final Duration rateLimitDelay;

  Duration calculateDelay(int retryCount, {RetryFailureType? failureType}) {
    final baseDelay = switch (failureType) {
      RetryFailureType.networkError => networkErrorDelay,
      RetryFailureType.serverError => serverErrorDelay,
      RetryFailureType.rateLimit => rateLimitDelay,
      _ => initialDelay,
    };

    final exponentialDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds *
              _pow(backoffMultiplier, retryCount))
          .toInt(),
    );

    final cappedDelay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

    return _applyJitter(cappedDelay);
  }

  bool shouldRetry(int retryCount) => retryCount < maxRetries;

  Duration _applyJitter(Duration delay) {
    final jitterMs = (delay.inMilliseconds * jitterFactor).toInt();
    final randomJitter = (jitterMs * 0.5).toInt();
    return Duration(milliseconds: delay.inMilliseconds - randomJitter);
  }

  int _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result.toInt();
  }

  static const RetryBackoffPolicy conservative = RetryBackoffPolicy(
    initialDelay: Duration(seconds: 10),
    maxDelay: Duration(hours: 1),
    maxRetries: 3,
    backoffMultiplier: 3.0,
  );

  static const RetryBackoffPolicy aggressive = RetryBackoffPolicy(
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(minutes: 5),
    maxRetries: 10,
    backoffMultiplier: 1.5,
  );
}

enum RetryFailureType {
  networkError,
  serverError,
  rateLimit,
  timeout,
  unknown,
}
