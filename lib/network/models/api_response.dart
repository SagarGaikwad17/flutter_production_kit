import 'package:flutter_production_kit/network/models/pagination.dart';

/// Typed API response with metadata.
///
/// Design rationale:
/// - [data] is raw — the API client never deserializes to domain types.
///   Deserialization is handled by the caller, keeping the client generic.
/// - [traceId] enables distributed tracing correlation.
/// - [wasServedFromCache] distinguishes cached vs fresh responses.
/// - [pagination] is populated for list endpoints.
/// - [warnings] carry non-fatal server-side notices (e.g., "this field is deprecated").
class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.headers = const {},
    this.traceId,
    this.wasServedFromCache = false,
    this.cacheKey,
    this.pagination,
    this.warnings = const [],
    this.requestDuration,
  });

  final int statusCode;
  final T data;
  final Map<String, String> headers;
  final String? traceId;
  final bool wasServedFromCache;
  final String? cacheKey;
  final PaginationInfo? pagination;
  final List<String> warnings;
  final Duration? requestDuration;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  @override
  String toString() =>
      'ApiResponse($statusCode, cached: $wasServedFromCache, duration: ${requestDuration?.inMilliseconds}ms)';
}
