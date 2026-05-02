import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Step 6: Resolves feature flags from remote config + env defaults.
///
/// Failure mode: recoverable — uses defaults if remote config unavailable.
///
/// Merge strategy:
/// Remote config values take precedence over env defaults.
/// If a specific remote config key is missing, env default is used.
/// This ensures feature flags always have a deterministic value.
class FeatureFlagPreloadStep {
  static const String _tag = 'FeatureFlagPreloadStep';

  Future<void> execute(BootstrapContext ctx) async {
    AppLogger.info(_tag, 'Resolving feature flags...');

    final defaults = FlavorConfig.instance.env.featureFlagDefaults;
    final remote = ctx.remoteConfigValues;

    bool resolve(String key, bool defaultValue) {
      if (remote == null) return defaultValue;
      final val = remote[key];
      if (val is bool) return val;
      return defaultValue;
    }

    ctx.enableNewOnboarding = resolve('enable_new_onboarding', defaults.enableNewOnboarding);
    ctx.enableBiometricLogin = resolve('enable_biometric_login', defaults.enableBiometricLogin);
    ctx.enableDarkMode = resolve('enable_dark_mode', defaults.enableDarkMode);
    ctx.enablePushNotifications = resolve('enable_push_notifications', defaults.enablePushNotifications);
    ctx.enableInAppReview = resolve('enable_in_app_review', defaults.enableInAppReview);
    ctx.enableAnalyticsDashboard = resolve('enable_analytics_dashboard', defaults.enableAnalyticsDashboard);

    final source = remote != null ? 'remote config' : 'env defaults (remote config unavailable)';
    AppLogger.info(_tag, 'Feature flags resolved from $source.');
    AppLogger.debug(_tag, 'Flags: onboarding=${ctx.enableNewOnboarding}, '
        'biometric=${ctx.enableBiometricLogin}, '
        'darkMode=${ctx.enableDarkMode}');
  }
}
