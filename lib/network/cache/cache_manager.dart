import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/cache/cache_entry.dart';
import 'package:flutter_production_kit/network/cache/cache_policy.dart';

/// In-memory cache manager with versioning and stale-while-revalidate support.
///
/// Design rationale:
/// - Memory-only cache — no disk persistence. This avoids stale data after
///   app restarts and simplifies cache invalidation.
/// - LRU-style eviction when [maxEntries] is reached.
/// - Version-based invalidation: incrementing the version in [CachePolicy]
///   automatically invalidates all entries from the previous version.
/// - Stale-while-revalidate: serves stale data immediately, fetches fresh
///   data in background, then updates the cache.
/// - Thread-safe: all operations are synchronous on a Map.
class CacheManager {
  CacheManager({
    this.maxGlobalEntries = 500,
  });

  static const String _tag = 'CacheManager';

  final int maxGlobalEntries;
  final Map<String, CacheEntry> _cache = {};
  final List<String> _accessOrder = [];

  /// Number of cached entries.
  int get size => _cache.length;

  /// Get a cached response.
  ///
  /// Returns null if no entry exists or the entry is expired.
  CacheEntry? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    _touch(key);

    if (entry.isExpired) {
      AppLogger.debug(_tag, 'Cache entry expired: $key');
      remove(key);
      return null;
    }

    AppLogger.trace(_tag, 'Cache hit: $key (stale: ${entry.isStale})');
    return entry;
  }

  /// Get a cached entry even if stale (for stale-while-revalidate).
  CacheEntry? getStale(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    _touch(key);

    if (entry.isExpired) {
      AppLogger.debug(_tag, 'Cache entry expired (stale-while-revalidate): $key');
      return null;
    }

    AppLogger.debug(_tag, 'Cache hit (stale): $key');
    return entry;
  }

  /// Store a response in the cache.
  void put(CacheEntry entry) {
    _evictIfNeeded();

    _cache[entry.key] = entry;
    if (!_accessOrder.contains(entry.key)) {
      _accessOrder.add(entry.key);
    }

    AppLogger.debug(_tag, 'Cache stored: ${entry.key} '
        '(expires: ${entry.expiresAt}, version: ${entry.version})');
  }

  /// Remove a specific cache entry.
  void remove(String key) {
    _cache.remove(key);
    _accessOrder.remove(key);
    AppLogger.debug(_tag, 'Cache removed: $key');
  }

  /// Remove all cache entries matching a prefix.
  ///
  /// Used for invalidation on write operations.
  void removeByPrefix(String prefix) {
    final keysToRemove = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      remove(key);
    }
    AppLogger.info(_tag, 'Cache invalidated: ${keysToRemove.length} entries with prefix "$prefix"');
  }

  /// Remove all cache entries for a specific policy version.
  ///
  /// When the API schema changes, increment the version in [CachePolicy]
  /// and call this to clear all old entries.
  void removeByVersion(int version, {String? prefix}) {
    final keysToRemove = _cache.entries
        .where((e) {
          final matchesVersion = e.value.version == version;
          final matchesPrefix = prefix == null || e.key.startsWith(prefix);
          return matchesVersion && matchesPrefix;
        })
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      remove(key);
    }

    AppLogger.info(_tag, 'Cache invalidated: ${keysToRemove.length} entries '
        'for version $version${prefix != null ? ' (prefix: $prefix)' : ''}');
  }

  /// Clear all cached entries.
  void clear() {
    final count = _cache.length;
    _cache.clear();
    _accessOrder.clear();
    AppLogger.info(_tag, 'Cache cleared: $count entries removed.');
  }

  /// Remove expired entries.
  int pruneExpired() {
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      AppLogger.debug(_tag, 'Cache pruned: ${expiredKeys.length} expired entries removed.');
    }

    return expiredKeys.length;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _touch(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  void _evictIfNeeded() {
    if (_cache.length < maxGlobalEntries) return;

    final evictCount = (maxGlobalEntries * 0.1).ceil();
    AppLogger.debug(_tag, 'Cache full — evicting $evictCount least recently used entries.');

    for (int i = 0; i < evictCount && _accessOrder.isNotEmpty; i++) {
      final oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
    }
  }
}
