import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/cache/cache_entry.dart';
import 'package:flutter_production_kit/network/cache/cache_manager.dart';
import 'package:flutter_production_kit/network/cache/cache_policy.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/models/api_response.dart';
import 'package:flutter_production_kit/network/tracing/network_observer.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Cache interceptor — serves cached responses when available.
///
/// Design rationale:
/// - Only applies to GET requests (write operations are never cached).
/// - If a fresh cached entry exists, it's returned immediately (no network).
/// - If a stale entry exists and [staleWhileRevalidate] is enabled:
///   1. Serve stale immediately.
///   2. Fire a background refresh to update the cache.
///   3. The stale response is returned to the caller.
/// - Cache keys include version prefix — incrementing version invalidates all.
/// - On successful write operations with [invalidateOnWrite], related cache
///   entries are invalidated.
class CacheInterceptor {
  CacheInterceptor({
    required CacheManager cacheManager,
    required NetworkObserver observer,
  })  : _cache = cacheManager,
        _observer = observer;

  static const String _tag = 'CacheInterceptor';

  final CacheManager _cache;
  final NetworkObserver _observer;

  /// Try to serve a cached response.
  ///
  /// Returns a [CachedResponse] if cache can serve the request.
  /// Returns null if the request should go to the network.
  Future<CachedResponse?> tryServe({
    required ApiRequestContext context,
    required CachePolicy policy,
    required RequestTrace trace,
  }) async {
    if (!policy.enabled || context.method != HttpMethod.get) {
      return null;
    }

    final cacheKey = policy.buildKey(context.path, context.queryParameters);
    if (cacheKey.isEmpty) return null;

    final entry = _cache.get(cacheKey);
    if (entry != null) {
      _observer.onCacheEvent(
        cacheKey: cacheKey,
        action: CacheEventAction.hit,
        servedFromCache: true,
      );

      trace.addPhase(
        name: 'cache_hit',
        duration: Duration.zero,
        success: true,
        detail: 'served_from_cache',
      );

      return CachedResponse(
        entry: entry,
        cacheKey: cacheKey,
        isStale: false,
      );
    }

    // Try stale-while-revalidate.
    if (policy.staleWhileRevalidate) {
      final staleEntry = _cache.getStale(cacheKey);
      if (staleEntry != null) {
        _observer.onCacheEvent(
          cacheKey: cacheKey,
          action: CacheEventAction.stale_hit,
          servedFromCache: true,
        );

        trace.addPhase(
          name: 'cache_stale_hit',
          duration: Duration.zero,
          success: true,
          detail: 'served_stale_while_revalidate',
        );

        return CachedResponse(
          entry: staleEntry,
          cacheKey: cacheKey,
          isStale: true,
        );
      }
    }

    _observer.onCacheEvent(
      cacheKey: cacheKey,
      action: CacheEventAction.miss,
    );

    return null;
  }

  /// Store a response in the cache after a successful request.
  void store({
    required ApiRequestContext context,
    required CachePolicy policy,
    required ApiResponse<dynamic> response,
  }) {
    if (!policy.enabled || context.method != HttpMethod.get) return;
    if (!response.isSuccess) return;

    final cacheKey = policy.buildKey(context.path, context.queryParameters);
    if (cacheKey.isEmpty) return;

    final entry = CacheEntry(
      key: cacheKey,
      data: response.data,
      statusCode: response.statusCode,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(policy.ttl),
      version: policy.version,
      etag: response.headers['etag'],
      lastModified: response.headers['last-modified'] != null
          ? DateTime.tryParse(response.headers['last-modified']!)
          : null,
      headers: response.headers,
    );

    _cache.put(entry);

    _observer.onCacheEvent(
      cacheKey: cacheKey,
      action: CacheEventAction.stored,
    );
  }

  /// Invalidate cache entries after a successful write operation.
  void invalidateOnWrite(ApiRequestContext context, CachePolicy policy) {
    if (!policy.invalidateOnWrite) return;

    final prefix = policy.cacheKeyPrefix.isEmpty
        ? context.path.split('/').take(2).join('/')
        : policy.cacheKeyPrefix;

    _cache.removeByPrefix(prefix);

    _observer.onCacheEvent(
      cacheKey: prefix,
      action: CacheEventAction.invalidated,
    );

    AppLogger.info(_tag, 'Cache invalidated for prefix: $prefix');
  }
}

class CachedResponse {
  const CachedResponse({
    required this.entry,
    required this.cacheKey,
    required this.isStale,
  });

  final CacheEntry entry;
  final String cacheKey;
  final bool isStale;
}
