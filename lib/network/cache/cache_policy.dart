/// Cache policy for API responses.
///
/// Design rationale:
/// - Cache is opt-in per endpoint — nothing is cached by default.
/// - [ttl] controls how long a response is considered fresh.
/// - [staleWhileRevalidate] allows serving stale data while fetching fresh
///   data in the background (improves perceived performance).
/// - [invalidateOnWrite] automatically invalidates related cache entries
///   when a write operation succeeds.
/// - [version] enables cache versioning — incrementing the version invalidates
///   all entries from the previous version (useful for schema changes).
class CachePolicy {
  const CachePolicy({
    this.enabled = false,
    this.ttl = const Duration(minutes: 5),
    this.staleWhileRevalidate = false,
    this.invalidateOnWrite = false,
    this.version = 1,
    this.maxEntries = 100,
    this.cacheKeyPrefix = '',
  });

  final bool enabled;
  final Duration ttl;
  final bool staleWhileRevalidate;
  final bool invalidateOnWrite;
  final int version;
  final int maxEntries;
  final String cacheKeyPrefix;

  /// No caching.
  static const none = CachePolicy(enabled: false);

  /// Short-lived cache (30 seconds) for frequently accessed data.
  static const shortLived = CachePolicy(
    enabled: true,
    ttl: Duration(seconds: 30),
    staleWhileRevalidate: true,
  );

  /// Medium-lived cache (5 minutes) for semi-static data.
  static const medium = CachePolicy(
    enabled: true,
    ttl: Duration(minutes: 5),
    staleWhileRevalidate: true,
  );

  /// Long-lived cache (1 hour) for static reference data.
  static const longLived = CachePolicy(
    enabled: true,
    ttl: Duration(hours: 1),
    staleWhileRevalidate: false,
  );

  /// Compute the full cache key including version prefix.
  String buildKey(String path, Map<String, String> queryParameters) {
    if (!enabled) return '';
    final query = queryParameters.entries
        .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
    final queryString = query.map((e) => '${e.key}=${e.value}').join('&');
    final baseKey = queryString.isEmpty ? path : '$path?$queryString';
    return '${cacheKeyPrefix}v${version}_$baseKey';
  }
}
