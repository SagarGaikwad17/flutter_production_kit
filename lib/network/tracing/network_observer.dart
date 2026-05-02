import 'dart:async';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Observability layer for the API runtime.
///
/// Design rationale:
/// - Broadcasts request lifecycle events for monitoring, analytics, and debugging.
/// - Observers are decoupled — adding a new observer doesn't change the client.
/// - Sensitive data (tokens, request bodies) is NEVER included in events.
/// - Latency percentiles can be computed from [RequestCompletedEvent] timestamps.
class NetworkObserver {
  NetworkObserver();

  static const String _tag = 'NetworkObserver';

  final StreamController<NetworkEvent> _controller =
      StreamController<NetworkEvent>.broadcast();

  Stream<NetworkEvent> get eventStream => _controller.stream;

  /// Emit a request started event.
  void onRequestStarted(RequestTrace trace) {
    _emit(RequestStartedEvent(trace));
  }

  /// Emit a request completed event.
  void onRequestCompleted(RequestTrace trace) {
    _emit(RequestCompletedEvent(trace));

    if (trace.totalDuration != null) {
      final ms = trace.totalDuration!.inMilliseconds;
      if (ms > 3000) {
        AppLogger.warning(_tag, 'Slow request: ${trace.summary}');
      } else {
        AppLogger.trace(_tag, 'Request completed: ${trace.summary}');
      }
    }
  }

  /// Emit a retry event.
  void onRetry({
    required String traceId,
    required String path,
    required int attemptNumber,
    required Duration delay,
    required String reason,
  }) {
    _emit(RetryEvent(
      traceId: traceId,
      path: path,
      attemptNumber: attemptNumber,
      delay: delay,
      reason: reason,
    ));

    AppLogger.info(_tag, 'Retry: $path (attempt $attemptNumber, delay: ${delay.inMilliseconds}ms, reason: $reason)');
  }

  /// Emit a deduplication event.
  void onDeduplication({
    required String dedupKey,
    required int waiterCount,
  }) {
    _emit(DeduplicationEvent(
      dedupKey: dedupKey,
      waiterCount: waiterCount,
    ));
  }

  /// Emit a cache event.
  void onCacheEvent({
    required String cacheKey,
    required CacheEventAction action,
    bool servedFromCache = false,
  }) {
    _emit(CacheEvent(
      cacheKey: cacheKey,
      action: action,
      servedFromCache: servedFromCache,
    ));
  }

  /// Emit a dangerous endpoint block event.
  void onEndpointBlocked({
    required String path,
    required String blockReason,
  }) {
    _emit(EndpointBlockedEvent(
      path: path,
      blockReason: blockReason,
    ));

    AppLogger.warning(_tag, 'Endpoint blocked: $path (reason: $blockReason)');
  }

  /// Emit a rate limit event.
  void onRateLimited({
    required String path,
    Duration? retryAfter,
    String? limitType,
  }) {
    _emit(RateLimitEvent(
      path: path,
      retryAfter: retryAfter,
      limitType: limitType,
    ));

    AppLogger.warning(_tag, 'Rate limited: $path${retryAfter != null ? ' (retry after: ${retryAfter.inSeconds}s)' : ''}');
  }

  void _emit(NetworkEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}

// ── Network Events ───────────────────────────────────────────────────────────

sealed class NetworkEvent {
  const NetworkEvent();
}

final class RequestStartedEvent extends NetworkEvent {
  const RequestStartedEvent(this.trace);
  final RequestTrace trace;
}

final class RequestCompletedEvent extends NetworkEvent {
  const RequestCompletedEvent(this.trace);
  final RequestTrace trace;
}

final class RetryEvent extends NetworkEvent {
  const RetryEvent({
    required this.traceId,
    required this.path,
    required this.attemptNumber,
    required this.delay,
    required this.reason,
  });

  final String traceId;
  final String path;
  final int attemptNumber;
  final Duration delay;
  final String reason;
}

final class DeduplicationEvent extends NetworkEvent {
  const DeduplicationEvent({
    required this.dedupKey,
    required this.waiterCount,
  });

  final String dedupKey;
  final int waiterCount;
}

final class CacheEvent extends NetworkEvent {
  const CacheEvent({
    required this.cacheKey,
    required this.action,
    this.servedFromCache = false,
  });

  final String cacheKey;
  final CacheEventAction action;
  final bool servedFromCache;
}

enum CacheEventAction { hit, miss, stale_hit, stored, invalidated }

final class EndpointBlockedEvent extends NetworkEvent {
  const EndpointBlockedEvent({
    required this.path,
    required this.blockReason,
  });

  final String path;
  final String blockReason;
}

final class RateLimitEvent extends NetworkEvent {
  const RateLimitEvent({
    required this.path,
    this.retryAfter,
    this.limitType,
  });

  final String path;
  final Duration? retryAfter;
  final String? limitType;
}
