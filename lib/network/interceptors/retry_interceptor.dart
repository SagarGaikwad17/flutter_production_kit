import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/failures/api_failure.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/retry/retry_engine.dart';
import 'package:flutter_production_kit/network/tracing/request_trace.dart';

/// Retry interceptor — handles retry logic after request failure.
///
/// Design rationale:
/// - Delegates retry decisions to [RetryEngine] (not hardcoded).
/// - Exponential backoff with jitter between retries.
/// - Each retry attempt is recorded in the trace.
/// - The interceptor respects the dangerous endpoint guard's block decisions.
class RetryInterceptor {
  RetryInterceptor({
    required RetryEngine retryEngine,
  }) : _retryEngine = retryEngine;

  static const String _tag = 'RetryInterceptor';

  final RetryEngine _retryEngine;

  /// Execute the request with retry support.
  ///
  /// [requestExecutor] is called to perform the actual HTTP request.
  /// If it fails, the retry engine decides whether to retry.
  Future<http.StreamedResponse> execute({
    required http.Request request,
    required ApiRequestContext context,
    required RequestTrace trace,
    required Future<http.StreamedResponse> Function(http.Request) requestExecutor,
  }) async {
    int attempt = 0;
    http.Request currentRequest = request;

    while (true) {
      final phaseStart = DateTime.now();

      try {
        final response = await requestExecutor(currentRequest);
        final phaseDuration = DateTime.now().difference(phaseStart);

        if (attempt > 0) {
          trace.recordAttempt(
            attemptNumber: attempt,
            statusCode: response.statusCode,
            duration: phaseDuration,
            success: response.statusCode < 400,
            failureType: response.statusCode >= 400 ? 'http_${response.statusCode}' : null,
          );
        }

        trace.addPhase(
          name: attempt == 0 ? 'request' : 'request_retry_$attempt',
          duration: phaseDuration,
          success: response.statusCode < 400,
        );

        return response;
      } catch (e) {
        final phaseDuration = DateTime.now().difference(phaseStart);

        if (attempt > 0) {
          trace.recordAttempt(
            attemptNumber: attempt,
            statusCode: null,
            duration: phaseDuration,
            success: false,
            failureType: e.runtimeType.toString(),
          );
        }

        final failure = _classifyError(e, trace, context);

        final decision = _retryEngine.evaluate(
          request: context,
          failure: failure,
          attemptNumber: attempt,
        );

        return switch (decision) {
          RetryDecisionRetry(:final delay) =>
            _handleRetry(
              delay: delay,
              attempt: attempt,
              trace: trace,
              context: context,
              requestExecutor: requestExecutor,
              currentRequest: currentRequest,
            ),
          RetryDecisionNoRetry() =>
            throw failure,
        };
      }
    }
  }

  Future<http.StreamedResponse> _handleRetry({
    required Duration delay,
    required int attempt,
    required RequestTrace trace,
    required ApiRequestContext context,
    required Future<http.StreamedResponse> Function(http.Request) requestExecutor,
    required http.Request currentRequest,
  }) async {
    final newAttempt = attempt + 1;

    AppLogger.info(
      _tag,
      'Retrying ${context.path} (attempt $newAttempt, delay: ${delay.inMilliseconds}ms)',
    );

    await Future.delayed(delay);

    // Rebuild request for retry (fresh timestamp, etc.).
    final retryRequest = _cloneRequest(currentRequest);

    trace.addPhase(
      name: 'retry_delay_$newAttempt',
      duration: delay,
      success: true,
      detail: 'backoff_before_retry',
    );

    return execute(
      request: retryRequest,
      context: context,
      trace: trace,
      requestExecutor: requestExecutor,
    );
  }

  ApiFailure _classifyError(
    Object e,
    RequestTrace trace,
    ApiRequestContext context,
  ) {
    if (e is ApiFailure) return e;
    return GenericApiFailure(
      message: 'Request failed: $e',
      traceId: trace.traceId,
      cause: e,
    );
  }

  http.Request _cloneRequest(http.Request original) {
    return http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = original.bodyBytes
      ..followRedirects = original.followRedirects
      ..maxRedirects = original.maxRedirects
      ..persistentConnection = original.persistentConnection;
  }
}
