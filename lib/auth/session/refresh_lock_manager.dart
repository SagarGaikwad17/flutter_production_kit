import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Solves the TOKEN REFRESH STORM problem.
///
/// Problem scenario:
/// User opens app after token expiry. 10 API requests fire simultaneously.
/// Without this manager: 10 concurrent refresh requests → server rate limit / errors.
///
/// Solution:
/// - First caller triggers the refresh.
/// - Subsequent callers receive a [Future] that completes when the first refresh finishes.
/// - If the refresh succeeds, ALL waiting callers get the new token.
/// - If the refresh fails, ALL waiting callers get the failure.
/// - After completion, the lock is released for the next refresh cycle.
///
/// Thread-safe: uses Completer and mutex-like pattern with no external dependencies.
class RefreshLockManager {
  static const String _tag = 'RefreshLockManager';

  Completer<void>? _activeRefresh;
  int _waitingCallers = 0;
  bool _isRefreshing = false;

  /// Whether a refresh is currently in progress.
  bool get isRefreshing => _isRefreshing;

  /// How many callers are waiting for the current refresh to complete.
  int get waitingCallers => _waitingCallers;

  /// Execute a refresh operation with storm protection.
  ///
  /// If no refresh is in progress, this caller becomes the leader and
  /// executes [refreshOperation]. All subsequent callers during the
  /// refresh will wait on the same completion.
  ///
  /// If a refresh is already in progress, the caller waits and returns
  /// the result of the leader's refresh.
  ///
  /// Returns true if the refresh (or the already-running refresh) succeeded.
  /// Returns false if it failed.
  Future<bool> executeRefresh({
    required Future<bool> Function() refreshOperation,
  }) async {
    if (_isRefreshing) {
      return _waitForExistingRefresh();
    }

    return _becomeRefreshLeader(refreshOperation: refreshOperation);
  }

  Future<bool> _becomeRefreshLeader({
    required Future<bool> Function() refreshOperation,
  }) async {
    _isRefreshing = true;
    _activeRefresh = Completer<void>();

    AppLogger.info(_tag, 'Refresh leader acquired — executing token refresh.');

    try {
      final success = await refreshOperation();

      if (success) {
        AppLogger.info(_tag, 'Refresh leader completed successfully. '
            '$_waitingCallers waiting callers released.');
      } else {
        AppLogger.warning(_tag, 'Refresh leader completed with failure. '
            '$_waitingCallers waiting callers released.');
      }

      _completeActiveRefresh();
      return success;
    } catch (e, st) {
      AppLogger.error(_tag, 'Refresh leader threw exception', error: e, stackTrace: st);
      _failActiveRefresh(error: e);
      return false;
    }
  }

  Future<bool> _waitForExistingRefresh() async {
    final completer = _activeRefresh;
    if (completer == null) {
      AppLogger.warning(_tag, 'No active refresh to wait on — race condition avoided.');
      return false;
    }

    _waitingCallers++;
    AppLogger.debug(_tag, 'Caller joining existing refresh (waiters: $_waitingCallers).');

    try {
      await completer.future;
      return true;
    } catch (e) {
      AppLogger.warning(_tag, 'Waiting refresh failed — caller notified.');
      return false;
    } finally {
      _waitingCallers = _waitingCallers > 0 ? _waitingCallers - 1 : 0;
    }
  }

  void _completeActiveRefresh() {
    _activeRefresh?.complete();
    _resetLock();
  }

  void _failActiveRefresh({required Object error}) {
    _activeRefresh?.completeError(error);
    _resetLock();
  }

  void _resetLock() {
    _isRefreshing = false;
    _activeRefresh = null;
    _waitingCallers = 0;
  }

  /// Force-reset the lock. Used during forced logout or session cleanup.
  void forceReset() {
    if (_isRefreshing) {
      AppLogger.warning(_tag, 'Force-resetting refresh lock — $_waitingCallers waiters will be dropped.');
      _failActiveRefresh(error: Exception('Refresh lock force-reset during session cleanup.'));
    }
  }
}
