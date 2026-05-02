import 'package:flutter_production_kit/bootstrap/bootstrap_step.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Traces bootstrap step execution with timing information.
///
/// Design rationale:
/// Bootstrap startup time is critical. [BootstrapTracer] records:
/// - The start time of each step.
/// - The elapsed time when it completes or fails.
/// - Whether the step succeeded, was skipped, or failed.
///
/// This trace is logged at INFO level (visible in dev/QA, suppressed in prod)
/// and optionally sent to crash reporting as metadata for bootstrap failures.
class BootstrapTracer {
  BootstrapTracer() : _startTime = DateTime.now();

  static const String _tag = 'BootstrapTracer';

  final DateTime _startTime;
  final Map<BootstrapStep, _StepTrace> _traces = {};

  DateTime? _stepStart;
  BootstrapStep? _currentStep;

  /// Call before executing a step.
  void beginStep(BootstrapStep step) {
    _currentStep = step;
    _stepStart = DateTime.now();
    AppLogger.info(_tag, '▶ Starting: ${step.displayName}');
  }

  /// Call after a step completes successfully.
  void completeStep(BootstrapStep step) {
    final elapsed = _elapsed();
    _traces[step] = _StepTrace(step: step, status: _StepStatus.success, elapsedMs: elapsed);
    AppLogger.info(_tag, '✓ Completed: ${step.displayName} (${elapsed}ms)');
    _reset();
  }

  /// Call when a step is skipped (e.g., Firebase skipped in dev).
  void skipStep(BootstrapStep step, {required String reason}) {
    final elapsed = _elapsed();
    _traces[step] = _StepTrace(step: step, status: _StepStatus.skipped, elapsedMs: elapsed);
    AppLogger.info(_tag, '⊘ Skipped: ${step.displayName} — $reason (${elapsed}ms)');
    _reset();
  }

  /// Call when a step fails.
  void failStep(BootstrapStep step, {required Object error, bool isBlocking = false}) {
    final elapsed = _elapsed();
    _traces[step] = _StepTrace(step: step, status: _StepStatus.failed, elapsedMs: elapsed, isBlocking: isBlocking);
    final severity = isBlocking ? '✗ BLOCKING FAILURE' : '⚠ Recoverable Failure';
    AppLogger.error(_tag, '$severity: ${step.displayName} (${elapsed}ms)', error: error);
    _reset();
  }

  /// Total elapsed time since [BootstrapTracer] was created.
  int get totalElapsedMs =>
      DateTime.now().difference(_startTime).inMilliseconds;

  /// Summary of all step traces.
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('Bootstrap Summary (${totalElapsedMs}ms total):');
    for (final trace in _traces.values) {
      final icon = switch (trace.status) {
        _StepStatus.success => '✓',
        _StepStatus.skipped => '⊘',
        _StepStatus.failed => '✗',
      };
      buffer.writeln('  $icon ${trace.step.displayName} (${trace.elapsedMs}ms)');
    }
    return buffer.toString();
  }

  int _elapsed() {
    return _stepStart != null
        ? DateTime.now().difference(_stepStart!).inMilliseconds
        : 0;
  }

  void _reset() {
    _currentStep = null;
    _stepStart = null;
  }
}

enum _StepStatus { success, skipped, failed }

class _StepTrace {
  const _StepTrace({
    required this.step,
    required this.status,
    required this.elapsedMs,
    this.isBlocking = false,
  });

  final BootstrapStep step;
  final _StepStatus status;
  final int elapsedMs;
  final bool isBlocking;
}
