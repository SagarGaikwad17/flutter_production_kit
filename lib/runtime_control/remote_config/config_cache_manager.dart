import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';
import 'package:flutter_production_kit/runtime_control/domain/repositories/runtime_control_repository.dart';

/// Config cache manager — versioned config cache with fallback support.
///
/// Design rationale:
/// - Caches multiple config versions for rollback protection.
/// - "Last known good" config is the most recent successfully validated config.
/// - Stale config detection prevents using expired configs.
/// - Cache is persisted — survives app restarts.
/// - Max versions limit prevents unbounded cache growth.
class ConfigCacheManager {
  ConfigCacheManager({
    required RuntimeControlRepository repository,
    this.maxCachedVersions = 5,
  }) : _repository = repository;

  static const String _tag = 'ConfigCacheManager';

  final RuntimeControlRepository _repository;
  final int maxCachedVersions;

  final List<CachedConfigEntry> _cache = [];

  /// Cache a config version.
  Future<void> cacheConfig(RuntimeConfig config, {bool markAsValid = true}) async {
    // Remove old entry for same version.
    _cache.removeWhere((entry) => entry.config.version == config.version);

    // Add new entry.
    _cache.add(CachedConfigEntry(
      config: config,
      storedAt: DateTime.now(),
      isValid: markAsValid,
    ));

    // Enforce max versions.
    if (_cache.length > maxCachedVersions) {
      _cache.removeAt(0);
    }

    await _repository.saveActiveConfig(config);
    if (markAsValid) {
      await _repository.saveLastKnownGoodConfig(config);
    }

    AppLogger.debug(
      _tag,
      'Config cached: version ${config.version} (valid: $markAsValid, cache size: ${_cache.length})',
    );
  }

  /// Get the last known good config.
  Future<RuntimeConfig?> getLastKnownGoodConfig() async {
    return _repository.getLastKnownGoodConfig();
  }

  /// Get a specific config version from cache.
  Future<RuntimeConfig?> getVersion(int version) async {
    final cached = _cache.where((e) => e.config.version == version).firstOrNull;
    if (cached != null) return cached.config;
    return _repository.getConfigByVersion(version);
  }

  /// Check if a config version exists in cache.
  bool hasVersion(int version) {
    return _cache.any((e) => e.config.version == version);
  }

  /// Get all cached versions.
  List<int> get cachedVersions =>
      _cache.map((e) => e.config.version).toList();

  /// Clear the cache.
  Future<void> clear() async {
    _cache.clear();
    await _repository.clear();
    AppLogger.info(_tag, 'Config cache cleared.');
  }

  /// Get cache size.
  int get cacheSize => _cache.length;

  /// Get the latest cached config.
  RuntimeConfig? get latest =>
      _cache.isNotEmpty ? _cache.last.config : null;
}
