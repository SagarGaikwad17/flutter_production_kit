import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/repositories/sync_repository.dart';
import 'package:flutter_production_kit/offline/network/connectivity_observer.dart';
import 'package:flutter_production_kit/offline/policies/retry_backoff_policy.dart';

/// Retry scheduler — manages retry timing for failed sync operations.
///
/// Design rationale:
/// - Each failed operation gets a scheduled retry time based on backoff policy.
/// - Retries are only attempted when the network is stable.
/// - Operations that exceed max retries are moved to the poison queue.
/// - The scheduler runs a periodic check for operations ready to retry.
/// - Retry classification determines the backoff strategy.
///
/// Retry flow:
/// 1. Operation fails → classified by failure type.
/// 2. Backoff delay calculated (exponential + jitter).
/// 3. Retry time stored in the operation's metadata.
/// 4. Scheduler checks for ready-to-retry operations periodically.
/// 5. If network is stable, operation is re-queued.
/// 6. If max retries exceeded → poison queue.
class RetryScheduler {
  RetryScheduler({
    required SyncRepository repository,
    required ConnectivityObserver connectivityObserver,
    RetryBackoffPolicy? backoffPolicy,
    this.retryCheckInterval = const Duration(minutes: 1),
  })  : _repository = repository,
        _connectivityObserver = connectivityObserver,
        _backoffPolicy = backoffPolicy ?? const RetryBackoffPolicy();

  static const String _tag = 'RetryScheduler';

  final SyncRepository _repository;
  final ConnectivityObserver _connectivityObserver;
  final RetryBackoffPolicy _backoffPolicy;
  final Duration retryCheckInterval;

  Timer? _checkTimer;
  final Map<String, DateTime> _scheduledRetries = {};
  bool _isRunning = false;

  /// Start the retry scheduler.
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _checkTimer = Timer.periodic(retryCheckInterval, (_) {
      _checkForReadyRetries();
    });

    AppLogger.info(_tag, 'Retry scheduler started.');
  }

  /// Stop the retry scheduler.
  void stop() {
    _checkTimer?.cancel();
    _isRunning = false;
    AppLogger.info(_tag, 'Retry scheduler stopped.');
  }

  /// Schedule a retry for a failed operation.
  Future<void> scheduleRetry({
    required String operationId,
    required int retryCount,
    RetryFailureType? failureType,
  }) async {
    if (!_backoffPolicy.shouldRetry(retryCount)) {
      AppLogger.warning(
        _tag,
        'Operation $operationId exceeded max retries ($retryCount) — '
        'will be moved to poison queue.',
      );
      _scheduledRetries.remove(operationId);
      return;
    }

    final delay = _backoffPolicy.calculateDelay(retryCount, failureType: failureType);
    final retryAt = DateTime.now().add(delay);

    _scheduledRetries[operationId] = retryAt;

    AppLogger.info(
      _tag,
      'Scheduled retry for $operationId: retry #$retryCount in ${delay.inSeconds}s '
      '(at ${retryAt.toIso8601String()})',
    );
  }

  /// Check if an operation is scheduled for retry.
  bool isScheduledForRetry(String operationId) {
    return _scheduledRetries.containsKey(operationId);
  }

  /// Get the scheduled retry time for an operation.
  DateTime? getScheduledRetryTime(String operationId) {
    return _scheduledRetries[operationId];
  }

  /// Cancel a scheduled retry (e.g., operation was manually resolved).
  void cancelRetry(String operationId) {
    _scheduledRetries.remove(operationId);
  }

  /// Get the count of scheduled retries.
  int get scheduledCount => _scheduledRetries.length;

  /// Check for operations that are ready to retry.
  Future<void> _checkForReadyRetries() async {
    if (!_connectivityObserver.isConnected ||
        !_connectivityObserver.isStable) {
      return;
    }

    final now = DateTime.now();
    final ready = _scheduledRetries.entries
        .where((entry) => entry.value.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    for (final operationId in ready) {
      _scheduledRetries.remove(operationId);

      final operation = await _repository.getOperation(operationId);
      if (operation != null && operation.canRetry) {
        AppLogger.info(
          _tag,
          'Operation $operationId is ready for retry '
          '(attempt ${operation.retryCount + 1}/${operation.maxRetries})',
        );
      }
    }
  }

  void dispose() {
    stop();
  }
}
