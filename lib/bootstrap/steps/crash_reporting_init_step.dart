import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Step 4: Initializes Firebase Crashlytics.
///
/// Failure mode: recoverable — the app can run without crash reporting.
/// A warning is logged and the failed step is recorded.
///
/// Design:
/// - Crashlytics is disabled for non-production flavors (no noise in dashboards).
/// - In dev/QA, Flutter's default error handler is preserved.
/// - In production, all Flutter and Dart async errors are routed to Crashlytics.
class CrashReportingInitStep {
  static const String _tag = 'CrashReportingInitStep';

  Future<void> execute(BootstrapContext ctx) async {
    if (!ctx.firebaseReady) {
      AppLogger.warning(_tag, 'Firebase not ready — skipping Crashlytics init.');
      return;
    }

    final flavor = FlavorConfig.instance.flavor;

    if (!flavor.crashReportingEnabled) {
      AppLogger.info(_tag, 'Crash reporting disabled for flavor: ${flavor.displayName}');
      // Ensure Crashlytics collection is off in dev to prevent accidental data.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      ctx.crashReportingReady = true;
      return;
    }

    try {
      AppLogger.info(_tag, 'Initializing Crashlytics...');

      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Route all Flutter framework errors to Crashlytics.
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };

      // Route uncaught async Dart errors to Crashlytics.
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      ctx.crashReportingReady = true;
      AppLogger.info(_tag, 'Crashlytics initialized.');
    } catch (e, st) {
      // Recoverable — log and continue.
      AppLogger.warning(_tag, 'Crashlytics init failed — continuing without crash reporting.',
          error: e, stackTrace: st);
    }
  }
}
