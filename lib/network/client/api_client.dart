import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/cache/cache_manager.dart';
import 'package:flutter_production_kit/network/cache/cache_policy.dart';
import 'package:flutter_production_kit/network/deduplication/request_deduplicator.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/guards/dangerous_endpoint_guard.dart';
import 'package:flutter_production_kit/network/interceptors/auth_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/cache_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/idempotency_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/logging_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/retry_interceptor.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/models/api_response.dart';
import 'package:flutter_production_kit/network/models/pagination.dart';
import 'package:flutter_production_kit/network/policies/endpoint_policy_registry.dart';
import 'package:flutter_production_kit/network/tracing/network_observer.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Enterprise API client — the central orchestrator for all HTTP operations.
///
/// Design rationale:
/// - Interceptor chain: dangerous guard → cache → dedup → auth → idempotency → retry → execute.
/// - Each interceptor has a single responsibility and can be tested in isolation.
/// - The client never logs sensitive data — all sanitization happens in interceptors.
/// - Response parsing is caller-responsible — the client returns raw data.
/// - Pagination helpers reduce boilerplate for list endpoints.
/// - All edge cases (token expiry, duplicate requests, dangerous retries) are handled.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required http.Client httpClient,
    required AuthInterceptor authInterceptor,
    required RetryInterceptor retryInterceptor,
    required CacheInterceptor cacheInterceptor,
    required IdempotencyInterceptor idempotencyInterceptor,
    required LoggingInterceptor loggingInterceptor,
    required DangerousEndpointGuard endpointGuard,
    required RequestDeduplicator deduplicator,
    required CacheManager cacheManager,
    required EndpointPolicyRegistry policyRegistry,
    required NetworkObserver observer,
    Duration? defaultTimeout,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _httpClient = httpClient,
        _authInterceptor = authInterceptor,
        _retryInterceptor = retryInterceptor,
        _cacheInterceptor = cacheInterceptor,
        _idempotencyInterceptor = idempotencyInterceptor,
        _loggingInterceptor = loggingInterceptor,
        _endpointGuard = endpointGuard,
        _deduplicator = deduplicator,
        _cacheManager = cacheManager,
        _policyRegistry = policyRegistry,
        _observer = observer,
        _defaultTimeout = defaultTimeout ?? const Duration(seconds: 30);

  static const String _tag = 'ApiClient';

  final String _baseUrl;
  final http.Client _httpClient;
  final AuthInterceptor _authInterceptor;
  final RetryInterceptor _retryInterceptor;
  final CacheInterceptor _cacheInterceptor;
  final IdempotencyInterceptor _idempotencyInterceptor;
  final LoggingInterceptor _loggingInterceptor;
  final DangerousEndpointGuard _endpointGuard;
  final RequestDeduplicator _deduplicator;
  final CacheManager _cacheManager;
  final EndpointPolicyRegistry _policyRegistry;
  final NetworkObserver _observer;
  final Duration _defaultTimeout;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Execute a GET request.
  Future<ApiResponse<T>> get<T>({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.get,
        path: path,
        criticality: EndpointCriticality.safe,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      ),
      parser: parser,
    );
  }

  /// Execute a POST request.
  Future<ApiResponse<T>> post<T>({
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? idempotencyKey,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.post,
        path: path,
        criticality: EndpointCriticality.standard,
        body: body,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
        idempotencyKey: idempotencyKey,
      ),
      parser: parser,
    );
  }

  /// Execute a PUT request.
  Future<ApiResponse<T>> put<T>({
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.put,
        path: path,
        criticality: EndpointCriticality.standard,
        body: body,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      ),
      parser: parser,
    );
  }

  /// Execute a PATCH request.
  Future<ApiResponse<T>> patch<T>({
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.patch,
        path: path,
        criticality: EndpointCriticality.standard,
        body: body,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      ),
      parser: parser,
    );
  }

  /// Execute a DELETE request.
  Future<ApiResponse<T>> delete<T>({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.delete,
        path: path,
        criticality: EndpointCriticality.destructive,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
      ),
      parser: parser,
    );
  }

  /// Execute a paginated GET request.
  Future<PaginatedResponse<T>> getPaginated<T>({
    required String path,
    required T Function(Map<String, dynamic> json) itemParser,
    Map<String, String>? queryParameters,
    String? cursor,
    int? page,
    int? pageSize,
  }) {
    final params = Map<String, String>.from(queryParameters ?? {});
    if (cursor != null) {
      params['cursor'] = cursor;
    }
    if (page != null) params['page'] = page.toString();
    if (pageSize != null) params['page_size'] = pageSize.toString();

    return _execute(
      context: ApiRequestContext(
        method: HttpMethod.get,
        path: path,
        criticality: EndpointCriticality.safe,
        queryParameters: params,
      ),
      parser: (data) {
        final json = data as Map<String, dynamic>;
        final itemsRaw = json['items'] as List<dynamic>? ?? json['data'] as List<dynamic>? ?? [];
        final items = itemsRaw
            .whereType<Map<String, dynamic>>()
            .map(itemParser)
            .toList();

        PaginationInfo? pagination;
        if (json.containsKey('pagination')) {
          pagination = PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>);
        } else if (json.containsKey('meta')) {
          pagination = PaginationInfo.fromJson(json['meta'] as Map<String, dynamic>);
        } else {
          pagination = PaginationInfo(
            totalItems: json['total'] as int?,
            hasMore: json['has_more'] as bool?,
            nextCursor: json['next_cursor'] as String?,
          );
        }

        return PaginatedResponse<T>(items: items, pagination: pagination);
      },
    ).then((response) => response.data as PaginatedResponse<T>);
  }

  /// Execute a critical request (payment, transaction, etc.).
  /// Requires an idempotency key — blocks if not provided.
  Future<ApiResponse<T>> critical<T>({
    required String path,
    required HttpMethod method,
    required String idempotencyKey,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _execute(
      context: ApiRequestContext(
        method: method,
        path: path,
        criticality: EndpointCriticality.critical,
        body: body,
        queryParameters: queryParameters ?? {},
        headers: headers ?? {},
        idempotencyKey: idempotencyKey,
      ),
      parser: parser,
    );
  }

  /// Cancel all pending deduplicated requests.
  void cancelPendingRequests() {
    _deduplicator.clearAll();
  }

  /// Clear all cached responses.
  void clearCache() {
    _cacheManager.clear();
  }

  /// Dispose resources.
  void dispose() {
    _httpClient.close();
  }

  // ── Core Execution Pipeline ────────────────────────────────────────────────

  Future<ApiResponse<T>> _execute<T>({
    required ApiRequestContext context,
    T Function(dynamic data)? parser,
  }) async {
    // Resolve policies from registry.
    final resolvedCriticality = _policyRegistry.resolveCriticality(context.path);
    final retryPolicy = _policyRegistry.resolveRetryPolicy(context.path);
    final cachePolicy = context.cachePolicyOverride != null
        ? CachePolicy(
            enabled: context.cachePolicyOverride!.enabled ?? false,
            ttl: context.cachePolicyOverride!.ttl ?? const Duration(minutes: 5),
            staleWhileRevalidate: context.cachePolicyOverride!.staleWhileRevalidate ?? false,
          )
        : _policyRegistry.resolveCachePolicy(context.path);

    // Apply resolved criticality.
    final effectiveContext = context.copyWith(criticality: resolvedCriticality);

    // Generate trace ID.
    final traceId = effectiveContext.traceId ?? _generateTraceId();
    final trace = RequestTrace(
      traceId: traceId,
      method: effectiveContext.method.value,
      path: effectiveContext.path,
    );

    _observer.onRequestStarted(trace);

    try {
      // Step 1: Dangerous endpoint guard.
      final blockResult = _endpointGuard.validate(effectiveContext);
      if (blockResult != null) {
        _observer.onEndpointBlocked(
          path: effectiveContext.path,
          blockReason: blockResult.blockReason,
        );
        throw blockResult;
      }

      // Step 2: Cache check (GET only).
      if (cachePolicy.enabled && effectiveContext.method == HttpMethod.get) {
        final cached = await _cacheInterceptor.tryServe(
          context: effectiveContext,
          policy: cachePolicy,
          trace: trace,
        );
        if (cached != null) {
          trace.endTime = DateTime.now();
          trace.statusCode = cached.entry.statusCode;
          trace.success = true;
          _observer.onRequestCompleted(trace);

          return ApiResponse<T>(
            statusCode: cached.entry.statusCode,
            data: cached.entry.data as T,
            headers: cached.entry.headers,
            traceId: traceId,
            wasServedFromCache: true,
            cacheKey: cached.cacheKey,
            requestDuration: trace.totalDuration,
          );
        }
      }

      // Step 3: Execute through the interceptor chain.
      final response = await _deduplicator.execute<ApiResponse<T>>(
        dedupKey: effectiveContext.dedupKey,
        requestExecutor: () => _runInterceptorChain<T>(
          context: effectiveContext,
          cachePolicy: cachePolicy,
          trace: trace,
          parser: parser,
        ),
      );

      return response;
    } catch (e) {
      trace.endTime = DateTime.now();
      trace.success = false;
      trace.failureReason = e.toString();
      _observer.onRequestCompleted(trace);

      if (e is ApiFailure) {
        rethrow;
      }
      throw GenericApiFailure(
        message: 'Request failed: $e',
        statusCode: null,
        traceId: traceId,
        cause: e,
      );
    }
  }

  Future<ApiResponse<T>> _runInterceptorChain<T>({
    required ApiRequestContext context,
    required CachePolicy cachePolicy,
    required RequestTrace trace,
    T Function(dynamic data)? parser,
  }) async {
    // Build the HTTP request.
    final uri = _buildUri(context);
    final request = http.Request(context.method.value, uri);

    // Apply default headers.
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';
    request.headers['X-Client-Platform'] = 'flutter';
    request.headers['X-Trace-Id'] = trace.traceId;

    // Apply custom headers.
    for (final entry in context.headers.entries) {
      request.headers[entry.key] = entry.value;
    }

    // Set body for non-GET requests.
    if (context.body != null) {
      request.body = jsonEncode(context.body);
    }

    // Logging: request.
    _loggingInterceptor.logRequest(context: context, trace: trace);

    // Apply idempotency key.
    final idempotentRequest = _idempotencyInterceptor.apply(
      request: request,
      context: context,
      trace: trace,
    );

    // Apply auth token.
    final authenticatedRequest = await _authInterceptor.apply(
      request: idempotentRequest,
      context: context,
      trace: trace,
    );

    // Execute with retry support.
    final response = await _retryInterceptor.execute(
      request: authenticatedRequest,
      context: context,
      trace: trace,
      requestExecutor: (req) => _httpClient.send(req),
    );

    // Read response body.
    final responseBytes = await response.stream.toBytes();
    final responseBody = utf8.decode(responseBytes);

    // Check for error responses.
    if (response.statusCode >= 400) {
      throw GenericApiFailure(
        message: 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        traceId: trace.traceId,
      );
    }

    // Parse response.
    final dynamic parsedData = _parseResponse(responseBody, parser);

    // Build response.
    final apiResponse = ApiResponse<T>(
      statusCode: response.statusCode,
      data: parsedData as T,
      headers: response.headers,
      traceId: trace.traceId,
      requestDuration: trace.totalDuration,
      pagination: parsedData is PaginatedResponse ? parsedData.pagination : null,
    );

    // Cache the response.
    if (cachePolicy.enabled && context.method == HttpMethod.get) {
      _cacheInterceptor.store(
        context: context,
        policy: cachePolicy,
        response: apiResponse,
      );
    }

    // Logging: response.
    _loggingInterceptor.logResponse(
      statusCode: response.statusCode,
      duration: trace.totalDuration ?? Duration.zero,
      context: context,
      trace: trace,
      success: true,
    );

    trace.endTime = DateTime.now();
    trace.statusCode = response.statusCode;
    trace.success = true;
    _observer.onRequestCompleted(trace);

    return apiResponse;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Uri _buildUri(ApiRequestContext context) {
    final baseUrl = context.baseUrl ?? _baseUrl;
    var uri = Uri.parse('$baseUrl${context.path}');

    if (context.queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: context.queryParameters);
    }

    return uri;
  }

  dynamic _parseResponse(String body, dynamic Function(dynamic)? parser) {
    if (body.isEmpty) return null;

    try {
      final decoded = jsonDecode(body);
      if (parser != null) {
        return parser(decoded);
      }
      return decoded;
    } catch (e) {
      return body;
    }
  }

  String _generateTraceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final random = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'req_${timestamp}_${random.toRadixString(36)}';
  }
}
