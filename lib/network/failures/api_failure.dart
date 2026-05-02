/// Sealed API failure hierarchy.
///
/// Design rationale:
/// Every failure mode has a distinct type. Call sites MUST handle each case
/// explicitly — no generic "try/catch" that swalls unexpected errors.
///
/// The failure model maps HTTP errors, network conditions, and business rules
/// into typed failures that the retry engine and UI can act on correctly.
sealed class ApiFailure implements Exception {
  const ApiFailure({
    required this.message,
    this.statusCode,
    this.traceId,
    this.cause,
    this.retryable = false,
  });

  final String message;
  final int? statusCode;
  final String? traceId;
  final Object? cause;
  final bool retryable;

  @override
  String toString() =>
      '$runtimeType: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}'
      '${retryable ? ' [retryable]' : ''}'
      '${traceId != null ? ' trace=$traceId' : ''}';
}

/// Generic API failure for uncategorized errors.
/// Use specific failure types whenever possible.
final class GenericApiFailure extends ApiFailure {
  const GenericApiFailure({
    required super.message,
    super.statusCode,
    super.traceId,
    super.cause,
    super.retryable,
  });
}

/// Request timed out before receiving a response.
final class ApiTimeoutFailure extends ApiFailure {
  const ApiTimeoutFailure({
    required super.message,
    super.traceId,
    super.cause,
    this.timeoutDuration,
  }) : super(retryable: true);

  final Duration? timeoutDuration;
}

/// No network connectivity available.
final class ApiNetworkUnavailableFailure extends ApiFailure {
  const ApiNetworkUnavailableFailure({
    required super.message,
    super.cause,
  }) : super(retryable: true);
}

/// Server returned 5xx — internal server error.
final class ApiServerFailure extends ApiFailure {
  const ApiServerFailure({
    required super.message,
    required super.statusCode,
    super.traceId,
    super.cause,
    super.retryable,
    this.isMaintenanceMode = false,
  });

  final bool isMaintenanceMode;
}

/// Server returned 4xx — client error.
final class ApiClientFailure extends ApiFailure {
  const ApiClientFailure({
    required super.message,
    required super.statusCode,
    super.traceId,
    super.cause,
  }) : super(retryable: false);
}

/// Authentication failed — token expired or invalid.
final class ApiAuthFailure extends ApiFailure {
  const ApiAuthFailure({
    required super.message,
    required super.statusCode,
    super.traceId,
    super.cause,
    this.requiresRefresh = false,
    this.sessionRevoked = false,
  });

  final bool requiresRefresh;
  final bool sessionRevoked;
}

/// Request was blocked by dangerous endpoint guard.
final class ApiBlockedFailure extends ApiFailure {
  const ApiBlockedFailure({
    required super.message,
    super.traceId,
    required this.blockReason,
  }) : super(retryable: false);

  final String blockReason;
}

/// Duplicate request was blocked by deduplication engine.
final class ApiDuplicateRequestFailure extends ApiFailure {
  const ApiDuplicateRequestFailure({
    required super.message,
    super.traceId,
    required this.dedupKey,
  }) : super(retryable: false);

  final String dedupKey;
}

/// Retry was blocked by retry policy (endpoint too dangerous to retry).
final class ApiRetryBlockedFailure extends ApiFailure {
  const ApiRetryBlockedFailure({
    required super.message,
    super.traceId,
    required this.blockedEndpoint,
    required this.originalStatusCode,
  }) : super(retryable: false);

  final String blockedEndpoint;
  final int originalStatusCode;
}

/// Partial success — some operations succeeded, others failed.
final class ApiPartialSuccessFailure extends ApiFailure {
  const ApiPartialSuccessFailure({
    required super.message,
    super.statusCode,
    super.traceId,
    required this.successCount,
    required this.failureCount,
    this.failedItems = const [],
  }) : super(retryable: false);

  final int successCount;
  final int failureCount;
  final List<String> failedItems;
}

/// Cache was invalidated due to version mismatch or staleness.
final class ApiCacheInvalidatedFailure extends ApiFailure {
  const ApiCacheInvalidatedFailure({
    required super.message,
    super.traceId,
    required this.cacheKey,
    this.reason,
  }) : super(retryable: false);

  final String cacheKey;
  final String? reason;
}

/// Backend requires a forced app update.
final class ApiUpdateRequiredFailure extends ApiFailure {
  const ApiUpdateRequiredFailure({
    required super.message,
    super.statusCode,
    super.traceId,
    this.minimumVersion,
  }) : super(retryable: false);

  final String? minimumVersion;
}

/// Request was rate-limited by the server.
final class ApiRateLimitFailure extends ApiFailure {
  const ApiRateLimitFailure({
    required super.message,
    super.statusCode,
    super.traceId,
    this.retryAfter,
    this.limitType,
  }) : super(retryable: true);

  final Duration? retryAfter;
  final String? limitType;
}

/// Request was cancelled (by user or timeout).
final class ApiCancelledFailure extends ApiFailure {
  const ApiCancelledFailure({
    required super.message,
    super.traceId,
    super.cause,
  }) : super(retryable: false);
}

/// Request body was malformed or failed validation.
final class ApiValidationFailure extends ApiFailure {
  const ApiValidationFailure({
    required super.message,
    super.statusCode,
    super.traceId,
    this.fieldErrors = const {},
  }) : super(retryable: false);

  final Map<String, String> fieldErrors;
}
