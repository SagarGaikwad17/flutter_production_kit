import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';

/// Request deduplication engine — coalesces identical in-flight requests.
///
/// Problem:
/// User taps a button that fires a GET request. Before the response arrives,
/// the user taps again OR a background refresh fires the same request.
/// Without deduplication: 2 identical requests hit the server.
///
/// Solution:
/// - Each in-flight request is tracked by its [dedupKey].
/// - If a duplicate request arrives while one is in-flight, the new request
///   subscribes to the original request's completion.
/// - Both callers receive the same result (success or failure).
/// - After completion, the entry is removed.
///
/// Thread-safe: uses Completer to share the result among all waiters.
class RequestDeduplicator {
  RequestDeduplicator({
    this.maxPendingRequests = 50,
  });

  static const String _tag = 'RequestDeduplicator';

  final int maxPendingRequests;

  final Map<String, _PendingRequest> _pendingRequests = {};

  /// Whether there are any pending requests.
  bool get hasPendingRequests => _pendingRequests.isNotEmpty;

  /// Number of currently in-flight deduplicated requests.
  int get pendingCount => _pendingRequests.length;

  /// Execute a request with deduplication.
  ///
  /// If a request with the same [dedupKey] is already in-flight, this caller
  /// waits for the original request to complete and shares its result.
  ///
  /// If no duplicate exists, this caller becomes the leader and executes
  /// [requestExecutor]. All subsequent duplicates wait on this execution.
  Future<T> execute<T>({
    required String dedupKey,
    required Future<T> Function() requestExecutor,
  }) async {
    final existing = _pendingRequests[dedupKey];
    if (existing != null) {
      AppLogger.debug(_tag, 'Duplicate request coalesced: $dedupKey '
          '(waiters: ${existing.waiterCount})');
      return existing.waitForResult() as T;
    }

    // Enforce max pending requests limit.
    if (_pendingRequests.length >= maxPendingRequests) {
      AppLogger.warning(_tag, 'Max pending requests ($maxPendingRequests) reached — '
          'dropping oldest for dedup key: $dedupKey');
      _evictOldest();
    }

    AppLogger.debug(_tag, 'New deduplicated request: $dedupKey');

    final completer = Completer<dynamic>();
    final pending = _PendingRequest(completer: completer, dedupKey: dedupKey);
    _pendingRequests[dedupKey] = pending;

    try {
      final result = await requestExecutor();
      completer.complete(result);
      return result as T;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _pendingRequests.remove(dedupKey);
      AppLogger.debug(_tag, 'Dedup request completed and removed: $dedupKey');
    }
  }

  /// Cancel a pending request by dedup key.
  void cancel(String dedupKey) {
    final pending = _pendingRequests.remove(dedupKey);
    if (pending != null) {
      pending.completeWithError(
        const ApiCancelledFailure(message: 'Request was cancelled by deduplicator.'),
      );
      AppLogger.info(_tag, 'Dedup request cancelled: $dedupKey');
    }
  }

  /// Clear all pending requests — used during forced logout or session reset.
  void clearAll() {
    final keys = _pendingRequests.keys.toList();
    for (final key in keys) {
      cancel(key);
    }
    AppLogger.info(_tag, 'All dedup requests cleared ($keys.length removed).');
  }

  void _evictOldest() {
    if (_pendingRequests.isNotEmpty) {
      final oldestKey = _pendingRequests.keys.first;
      _pendingRequests.remove(oldestKey);
    }
  }
}

class _PendingRequest {
  _PendingRequest({
    required this.completer,
    required this.dedupKey,
  });

  final Completer<dynamic> completer;
  final String dedupKey;
  int _waiterCount = 0;

  int get waiterCount => _waiterCount;

  Future<dynamic> waitForResult() {
    _waiterCount++;
    return completer.future;
  }

  void completeWithError(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }
}
