import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';
import 'package:flutter_production_kit/runtime_control/domain/exceptions/runtime_control_exception.dart';
import 'package:flutter_production_kit/runtime_control/domain/repositories/runtime_control_repository.dart';

/// Remote config manager — fetches and manages remote configuration.
///
/// Design rationale:
/// - Fetches config from the backend with timeout and retry support.
/// - Validates config before applying — prevents malformed configs.
/// - Caches config locally for offline access and app restart recovery.
/// - Maintains a "last known good" config for fallback when fetch fails.
/// - Version tracking prevents rollback to dangerous old configs.
/// - Environment validation prevents cross-environment config leaks.
/// - Signature verification prevents tampered configs.
///
/// Fetch flow:
/// 1. Check if fetch is needed (staleness, forced refresh).
/// 2. Fetch from backend with timeout.
/// 3. Validate config (structure, environment, version).
/// 4. If valid → save as active config + update last known good.
/// 5. If invalid → reject, use fallback, log the rejection.
class RemoteConfigManager {
  RemoteConfigManager({
    required RuntimeControlRepository repository,
    required ConfigFetcher fetcher,
    required ConfigValidator validator,
    this.environment = 'production',
    this.fetchTimeout = const Duration(seconds: 10),
    this.minFetchInterval = const Duration(minutes: 5),
  })  : _repository = repository,
        _fetcher = fetcher,
        _validator = validator;

  static const String _tag = 'RemoteConfigManager';

  final RuntimeControlRepository _repository;
  final ConfigFetcher _fetcher;
  final ConfigValidator _validator;
  final String environment;
  final Duration fetchTimeout;
  final Duration minFetchInterval;

  DateTime? _lastFetchTime;
  RuntimeConfig? _activeConfig;
  bool _isFetching = false;

  RuntimeConfig? get activeConfig => _activeConfig;
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Fetch remote config with safety checks.
  Future<ConfigFetchResult> fetchConfig({
    bool forceRefresh = false,
    Map<String, String>? headers,
  }) async {
    if (_isFetching) {
      return const ConfigFetchResultAlreadyFetching();
    }

    // Check if fetch is needed.
    if (!forceRefresh && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < minFetchInterval) {
        return ConfigFetchResultTooSoon(elapsed);
      }
    }

    _isFetching = true;

    try {
      // Fetch with timeout.
      final rawConfig = await _fetcher.fetch(
        timeout: fetchTimeout,
        headers: headers,
      ).timeout(
        fetchTimeout,
        onTimeout: () {
          throw const ConfigFetchTimeoutException(
            message: 'Config fetch timed out.',
            timeout: Duration(seconds: 10),
          );
        },
      );

      // Parse and validate.
      final config = await _validator.validate(rawConfig, environment);

      // Version check — prevent rollback to older config.
      final currentVersion = _activeConfig?.version ?? 0;
      if (config.version < currentVersion && !forceRefresh) {
        AppLogger.warning(
          _tag,
          'Config version rollback detected: ${config.version} < $currentVersion — rejecting.',
        );
        return ConfigFetchResultVersionRollback(
          requested: config.version,
          current: currentVersion,
        );
      }

      // Save as active.
      await _repository.saveActiveConfig(config);
      await _repository.saveLastKnownGoodConfig(config);
      _activeConfig = config;
      _lastFetchTime = DateTime.now();

      AppLogger.info(
        _tag,
        'Config fetched successfully: version ${config.version}, '
        '${config.featureFlags.length} flags, '
        '${config.killSwitches.length} kill switches.',
      );

      return ConfigFetchResultSuccess(config);
    } on ConfigFetchException catch (e) {
      AppLogger.error(_tag, 'Config fetch failed', error: e);
      return ConfigFetchResultError(e);
    } on ConfigValidationException catch (e) {
      AppLogger.error(_tag, 'Config validation failed', error: e);
      return ConfigFetchResultValidationError(e);
    } on ConfigParseException catch (e) {
      AppLogger.error(_tag, 'Config parse failed', error: e);
      return ConfigFetchResultParseError(e);
    } on EnvironmentMismatchException catch (e) {
      AppLogger.error(_tag, 'Environment mismatch', error: e);
      return ConfigFetchResultEnvironmentMismatch(e);
    } catch (e) {
      AppLogger.error(_tag, 'Unexpected config fetch error', error: e);
      return ConfigFetchResultUnknownError(e);
    } finally {
      _isFetching = false;
    }
  }

  /// Get the best available config — active, fallback, or empty.
  Future<RuntimeConfig?> getBestAvailableConfig() async {
    if (_activeConfig != null) return _activeConfig;

    // Try active from repository.
    _activeConfig = await _repository.getActiveConfig();
    if (_activeConfig != null) return _activeConfig;

    // Fallback to last known good.
    final fallback = await _repository.getLastKnownGoodConfig();
    if (fallback != null) {
      _activeConfig = fallback;
      AppLogger.info(_tag, 'Using last known good config as fallback.');
      return fallback;
    }

    AppLogger.warning(_tag, 'No config available — returning empty config.');
    return RuntimeConfig.empty;
  }

  /// Load config from cache (for app startup).
  Future<void> loadFromCache() async {
    _activeConfig = await _repository.getActiveConfig();
    _activeConfig ??= await _repository.getLastKnownGoodConfig();
  }
}

/// Abstract fetcher — implement to connect to your backend.
abstract class ConfigFetcher {
  const ConfigFetcher();
  Future<Map<String, dynamic>> fetch({
    Duration? timeout,
    Map<String, String>? headers,
  });
}

/// Abstract validator — implement to validate config structure.
abstract class ConfigValidator {
  const ConfigValidator();
  Future<RuntimeConfig> validate(Map<String, dynamic> rawConfig, String environment);
}

/// Result of a config fetch operation.
sealed class ConfigFetchResult {
  const ConfigFetchResult();
}

final class ConfigFetchResultSuccess extends ConfigFetchResult {
  const ConfigFetchResultSuccess(this.config);
  final RuntimeConfig config;
}

final class ConfigFetchResultAlreadyFetching extends ConfigFetchResult {
  const ConfigFetchResultAlreadyFetching();
}

final class ConfigFetchResultTooSoon extends ConfigFetchResult {
  const ConfigFetchResultTooSoon(this.timeSinceLastFetch);
  final Duration timeSinceLastFetch;
}

final class ConfigFetchResultVersionRollback extends ConfigFetchResult {
  const ConfigFetchResultVersionRollback({
    required this.requested,
    required this.current,
  });
  final int requested;
  final int current;
}

final class ConfigFetchResultError extends ConfigFetchResult {
  const ConfigFetchResultError(this.error);
  final ConfigFetchException error;
}

final class ConfigFetchResultValidationError extends ConfigFetchResult {
  const ConfigFetchResultValidationError(this.error);
  final ConfigValidationException error;
}

final class ConfigFetchResultParseError extends ConfigFetchResult {
  const ConfigFetchResultParseError(this.error);
  final ConfigParseException error;
}

final class ConfigFetchResultEnvironmentMismatch extends ConfigFetchResult {
  const ConfigFetchResultEnvironmentMismatch(this.error);
  final EnvironmentMismatchException error;
}

final class ConfigFetchResultUnknownError extends ConfigFetchResult {
  const ConfigFetchResultUnknownError(this.error);
  final Object error;
}
