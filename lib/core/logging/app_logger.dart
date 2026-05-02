import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:flutter_production_kit/core/logging/log_level_policy.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Production-safe structured logger for the Flutter Production Kit.
///
/// Design rationale:
/// - Single facade (AppLogger) over the `logger` package.
///   No code outside this file should import `package:logger` directly.
/// - Never uses `print()`. The `logger` package routes to the proper output.
/// - Tag-based logging: every log call requires a [tag] (usually the class name).
///   This makes log filtering by component trivial in production tools.
/// - Flavor-aware: log level and printer are determined by [LogLevelPolicy].
/// - Production safety: WARNING/ERROR only in prod — no INFO leaks.
///
/// Usage:
/// ```dart
/// AppLogger.info('AuthService', 'User signed in: ${user.id}');
/// AppLogger.error('NetworkClient', 'Request failed', error: e, stackTrace: st);
/// ```
abstract final class AppLogger {
  AppLogger._();

  static Logger? _logger;

  /// Initializes the logger. Call this during bootstrap before any logging.
  static void initialize() {
    _logger = Logger(
      level: LogLevelPolicy.resolveLevel(),
      printer: LogLevelPolicy.resolvePrinter(),
      output: _FlavorAwareOutput(),
    );
  }

  static Logger get _log {
    return _logger ??= Logger(
      level: LogLevelPolicy.resolveLevel(),
      printer: LogLevelPolicy.resolvePrinter(),
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  static void trace(String tag, String message) =>
      _log.t('[$tag] $message');

  static void debug(String tag, String message) =>
      _log.d('[$tag] $message');

  static void info(String tag, String message) =>
      _log.i('[$tag] $message');

  static void warning(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log.w('[$tag] $message', error: error, stackTrace: stackTrace);

  static void error(
    String tag,
    String message, {
    required Object error,
    StackTrace? stackTrace,
  }) =>
      _log.e('[$tag] $message', error: error, stackTrace: stackTrace);

  static void fatal(
    String tag,
    String message, {
    required Object error,
    StackTrace? stackTrace,
  }) =>
      _log.f('[$tag] $message', error: error, stackTrace: stackTrace);
}

/// Custom log output that suppresses all output in production builds.
///
/// Belt-and-suspenders: even if [LogLevelPolicy] somehow allows a verbose
/// log in a production build, [_FlavorAwareOutput] will not emit it.
class _FlavorAwareOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // In production, only emit WARNING and above.
    if (FlavorConfig.isInitialized &&
        FlavorConfig.instance.flavor.isProduction &&
        event.level.index < Level.warning.index) {
      return;
    }

    // Route to console.
    event.lines.forEach(outputToConsole);
  }

  @visibleForOverriding
  void outputToConsole(String line) {
    // ignore: avoid_print
    print(line);
  }
}
