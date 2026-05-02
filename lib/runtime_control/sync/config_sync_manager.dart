import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/remote_config/remote_config_manager.dart';
import 'package:flutter_production_kit/runtime_control/tracing/runtime_control_observer.dart';

/// Config sync manager — orchestrates periodic remote config synchronization.
///
/// Design rationale:
/// - Periodically fetches config from the backend.
/// - On fetch success: updates active config, notifies observers.
/// - On fetch failure: uses fallback config, logs the failure, retries later.
/// - Respects minimum fetch interval to avoid hammering the server.
/// - Supports manual refresh and forced refresh.
/// - Tracks sync status for monitoring.
///
/// Sync flow:
/// 1. Start periodic timer.
/// 2. On timer tick: check if fetch needed (staleness, network).
/// 3. Fetch config with timeout.
/// 4. On success: update active config, notify observers.
/// 5. On failure: use fallback, schedule retry with backoff.
class ConfigSyncManager {
  ConfigSyncManager({
    required RemoteConfigManager remoteConfigManager,
    required RuntimeControlObserver observer,
    this.syncInterval = const Duration(minutes: 15),
    this.initialFetchOnStart = true,
    this.retryBackoffMultiplier = 2.0,
    this.maxRetryBackoff = const Duration(minutes: 30),
  })  : _remoteConfigManager = remoteConfigManager,
        _observer = observer;

  static const String _tag = 'ConfigSyncManager';

  final RemoteConfigManager _remoteConfigManager;
  final RuntimeControlObserver _observer;
  final Duration syncInterval;
  final bool initialFetchOnStart;
  final double retryBackoffMultiplier;
  final Duration maxRetryBackoff;

  Timer? _syncTimer;
  bool _isRunning = false;
  Duration? _currentRetryDelay;
  int _consecutiveFailures = 0;
  SyncStatus _status = SyncStatus.idle;

  SyncStatus get status => _status;
  bool get isRunning => _isRunning;
  int get consecutiveFailures => _consecutiveFailures;

  /// Start the sync manager.
  Future<void> start() async {
    if (_isRunning) {
      AppLogger.info(_tag, 'Sync manager already running.');
      return;
    }

    _isRunning = true;
    _status = SyncStatus.running;

    AppLogger.info(_tag, 'Config sync manager started (interval: ${syncInterval.inMinutes}min)');

    // Initial fetch.
    if (initialFetchOnStart) {
      await _fetchAndSync(forceRefresh: true);
    }

    // Start periodic timer.
    _syncTimer = Timer.periodic(syncInterval, (_) {
      _fetchAndSync();
    });
  }

  /// Stop the sync manager.
  void stop() {
    _syncTimer?.cancel();
    _isRunning = false;
    _status = SyncStatus.stopped;
    AppLogger.info(_tag, 'Config sync manager stopped.');
  }

  /// Trigger a manual sync.
  Future<void> triggerSync({bool forceRefresh = false}) async {
    await _fetchAndSync(forceRefresh: forceRefresh);
  }

  /// Fetch and sync config.
  Future<void> _fetchAndSync({bool forceRefresh = false}) async {
    try {
      _status = SyncStatus.syncing;

      final result = await _remoteConfigManager.fetchConfig(
        forceRefresh: forceRefresh,
      );

      if (result is ConfigFetchResultSuccess) {
        _consecutiveFailures = 0;
        _currentRetryDelay = null;
        _status = SyncStatus.synced;
        _observer.onConfigSyncSuccess(result.config.version);
        AppLogger.info(
          _tag,
          'Config synced: version ${result.config.version} '
          '(${result.config.featureFlags.length} flags)',
        );
      } else if (result is ConfigFetchResultAlreadyFetching) {
        AppLogger.info(_tag, 'Config fetch already in progress — skipping.');
      } else if (result is ConfigFetchResultTooSoon) {
        AppLogger.debug(
          _tag,
          'Fetch too soon — ${result.timeSinceLastFetch.inSeconds}s since last fetch.',
        );
      } else if (result is ConfigFetchResultVersionRollback) {
        _observer.onConfigSyncRejected('version_rollback');
        AppLogger.warning(_tag, 'Config version rollback rejected.');
      } else if (result is ConfigFetchResultError) {
        _consecutiveFailures++;
        _status = SyncStatus.failed;
        _observer.onConfigSyncFailure(result.error.message);
        _scheduleRetry();
      } else if (result is ConfigFetchResultValidationError) {
        _consecutiveFailures++;
        _status = SyncStatus.failed;
        _observer.onConfigSyncFailure('validation: ${result.error.message}');
        _scheduleRetry();
      } else if (result is ConfigFetchResultParseError) {
        _consecutiveFailures++;
        _status = SyncStatus.failed;
        _observer.onConfigSyncFailure('parse: ${result.error.message}');
        _scheduleRetry();
      } else if (result is ConfigFetchResultEnvironmentMismatch) {
        _consecutiveFailures++;
        _status = SyncStatus.failed;
        _observer.onConfigSyncFailure('env_mismatch');
        AppLogger.error(
          _tag,
          'Environment mismatch — config rejected.',
          error: result.error,
        );
      } else if (result is ConfigFetchResultUnknownError) {
        _consecutiveFailures++;
        _status = SyncStatus.failed;
        _observer.onConfigSyncFailure(result.error.toString());
        _scheduleRetry();
      }
    } catch (e) {
      _consecutiveFailures++;
      _status = SyncStatus.failed;
      _observer.onConfigSyncFailure(e.toString());
      _scheduleRetry();
    }
  }

  /// Schedule a retry with exponential backoff.
  void _scheduleRetry() {
    _currentRetryDelay ??= syncInterval;
    _currentRetryDelay = Duration(
      milliseconds: (_currentRetryDelay!.inMilliseconds * retryBackoffMultiplier).toInt(),
    );

    if (_currentRetryDelay! > maxRetryBackoff) {
      _currentRetryDelay = maxRetryBackoff;
    }

    AppLogger.info(
      _tag,
      'Scheduling retry in ${_currentRetryDelay!.inSeconds}s '
      '(failure #$_consecutiveFailures)',
    );

    Timer(_currentRetryDelay!, () {
      if (_isRunning) {
        _fetchAndSync();
      }
    });
  }
}

enum SyncStatus {
  idle,
  running,
  syncing,
  synced,
  failed,
  stopped,
}
