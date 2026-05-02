import 'package:logger/logger.dart';
import 'package:flutter_production_kit/core/env/base_env.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Maps [AppLogLevel] to the `logger` package's [Level] enum.
///
/// Design rationale:
/// The mapping is centralized here so that changing log behavior for
/// a flavor only requires editing [LogLevelPolicy] — not every logger call.
///
/// Behavior by flavor:
/// - dev/demo: VERBOSE — full trace, pretty-printed with colors.
/// - qa:       INFO    — meaningful events only, no noise.
/// - staging:  WARNING — only warnings and errors.
/// - prod/wl:  WARNING — only warnings and errors. Never DEBUG or INFO.
abstract final class LogLevelPolicy {
  LogLevelPolicy._();

  /// Returns the `logger` [Level] for the current flavor.
  static Level resolveLevel() {
    if (!FlavorConfig.isInitialized) return Level.warning;
    return _toLoggerLevel(FlavorConfig.instance.env.minimumLogLevel);
  }

  /// Returns whether pretty-printing (colors, box drawing) is enabled.
  static bool resolvePrettyPrint() {
    if (!FlavorConfig.isInitialized) return false;
    return FlavorConfig.instance.env.prettyPrintLogs;
  }

  /// Returns the [LogPrinter] appropriate for the current flavor.
  static LogPrinter resolvePrinter() {
    final pretty = resolvePrettyPrint();
    return pretty
        ? PrettyPrinter(
            methodCount: 3,
            errorMethodCount: 10,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          )
        : SimplePrinter(colors: false, printTime: true);
  }

  static Level _toLoggerLevel(AppLogLevel level) => switch (level) {
        AppLogLevel.verbose => Level.trace,
        AppLogLevel.debug => Level.debug,
        AppLogLevel.info => Level.info,
        AppLogLevel.warning => Level.warning,
        AppLogLevel.error => Level.error,
        AppLogLevel.nothing => Level.off,
      };
}
