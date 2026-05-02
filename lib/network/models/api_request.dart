/// HTTP methods supported by the API client.
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
}

extension HttpMethodExtension on HttpMethod {
  String get value => name.toUpperCase();
  bool get isSafe => this == HttpMethod.get;
  bool get isIdempotent =>
      this == HttpMethod.get ||
      this == HttpMethod.put ||
      this == HttpMethod.delete;
}

/// Endpoint criticality classification.
///
/// Drives retry policy, idempotency requirements, and logging sensitivity.
enum EndpointCriticality {
  /// Safe reads — can be retried freely, cached aggressively.
  safe,

  /// Standard writes — limited retry, no auto-retry on partial failure.
  standard,

  /// Financial/transactional — NEVER auto-retry without idempotency key.
  critical,

  /// Destructive operations (delete, revoke) — single attempt only.
  destructive,

  /// Auth operations — special handling (token refresh integration).
  auth,
}

/// Request context — the structured representation of an API call.
///
/// Design rationale:
/// - Immutable: request context is built, then executed.
/// - [idempotencyKey] is required for critical/destructive endpoints.
/// - [retryOverride] allows per-request retry policy overrides.
/// - [traceId] enables distributed tracing across the interceptor chain.
class ApiRequestContext {
  const ApiRequestContext({
    required this.method,
    required this.path,
    required this.criticality,
    this.baseUrl,
    this.queryParameters = const {},
    this.body,
    this.headers = const {},
    this.idempotencyKey,
    this.retryOverride,
    this.cachePolicyOverride,
    this.traceId,
    this.timeout,
    this.tags = const [],
  });

  final HttpMethod method;
  final String path;
  final EndpointCriticality criticality;
  final String? baseUrl;
  final Map<String, String> queryParameters;
  final Map<String, dynamic>? body;
  final Map<String, String> headers;
  final String? idempotencyKey;
  final RetryPolicyOverride? retryOverride;
  final CachePolicyOverride? cachePolicyOverride;
  final String? traceId;
  final Duration? timeout;
  final List<String> tags;

  /// Unique key for request deduplication.
  String get dedupKey => '$method:$path:${_stableQueryString()}';

  String _stableQueryString() {
    if (queryParameters.isEmpty) return '';
    final sorted = queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => '${e.key}=${e.value}').join('&');
  }

  ApiRequestContext copyWith({
    HttpMethod? method,
    String? path,
    EndpointCriticality? criticality,
    String? baseUrl,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    String? idempotencyKey,
    RetryPolicyOverride? retryOverride,
    CachePolicyOverride? cachePolicyOverride,
    String? traceId,
    Duration? timeout,
    List<String>? tags,
  }) {
    return ApiRequestContext(
      method: method ?? this.method,
      path: path ?? this.path,
      criticality: criticality ?? this.criticality,
      baseUrl: baseUrl ?? this.baseUrl,
      queryParameters: queryParameters ?? this.queryParameters,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      retryOverride: retryOverride ?? this.retryOverride,
      cachePolicyOverride: cachePolicyOverride ?? this.cachePolicyOverride,
      traceId: traceId ?? this.traceId,
      timeout: timeout ?? this.timeout,
      tags: tags ?? this.tags,
    );
  }

  @override
  String toString() =>
      'ApiRequestContext(${method.value} $path, criticality: ${criticality.name})';
}

/// Per-request retry policy override.
class RetryPolicyOverride {
  const RetryPolicyOverride({
    this.maxRetries,
    this.retryableStatusCodes,
    this.blockRetry,
  });

  final int? maxRetries;
  final List<int>? retryableStatusCodes;
  final bool? blockRetry;
}

/// Per-request cache policy override.
class CachePolicyOverride {
  const CachePolicyOverride({
    this.enabled,
    this.ttl,
    this.staleWhileRevalidate,
  });

  final bool? enabled;
  final Duration? ttl;
  final bool? staleWhileRevalidate;
}
