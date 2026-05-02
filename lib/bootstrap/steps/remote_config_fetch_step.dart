import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Step 5: Fetches Firebase Remote Config values.
///
/// Failure mode: recoverable — app uses [FeatureFlagDefaults] as fallback.
///
/// Edge cases handled:
/// - Network unavailable → use cached/default values.
/// - Fetch throttled → use cached values (Firebase automatically caches).
/// - Firebase not ready → skip (ctx.remoteConfigValues stays null, step 6 uses defaults).
///
/// Fetch strategy by flavor:
/// - dev: minimumFetchInterval = 0 (always fresh)
/// - qa/staging: minimumFetchInterval = 1 hour
/// - prod/wl: minimumFetchInterval = 12 hours (respects Firebase quota)
class RemoteConfigFetchStep {
  static const String _tag = 'RemoteConfigFetchStep';

  Future<void> execute(BootstrapContext ctx) async {
    if (!ctx.firebaseReady) {
      AppLogger.warning(_tag, 'Firebase not ready — skipping remote config fetch.');
      return;
    }

    final flavor = FlavorConfig.instance.flavor;
    final fetchInterval = _resolveFetchInterval(flavor);

    try {
      AppLogger.info(_tag, 'Fetching remote config (interval: ${fetchInterval.inMinutes}min)...');

      final remoteConfig = FirebaseRemoteConfig.instance;

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: fetchInterval,
        ),
      );

      // Set defaults from env — these are used if fetch fails or remote config
      // is not yet published.
      final env = FlavorConfig.instance.env;
      await remoteConfig.setDefaults({
        'enable_new_onboarding': env.featureFlagDefaults.enableNewOnboarding,
        'enable_biometric_login': env.featureFlagDefaults.enableBiometricLogin,
        'enable_dark_mode': env.featureFlagDefaults.enableDarkMode,
        'enable_push_notifications': env.featureFlagDefaults.enablePushNotifications,
        'enable_in_app_review': env.featureFlagDefaults.enableInAppReview,
        'enable_analytics_dashboard': env.featureFlagDefaults.enableAnalyticsDashboard,
        'maintenance_mode_active': env.featureFlagDefaults.maintenanceModeActive,
        'minimum_required_version': env.featureFlagDefaults.minimumRequiredVersion,
      });

      final status = await remoteConfig.fetchAndActivate();
      AppLogger.info(_tag, 'Remote config fetch status: $status');

      // Extract all relevant values into the context.
      ctx.remoteConfigValues = {
        'enable_new_onboarding': remoteConfig.getBool('enable_new_onboarding'),
        'enable_biometric_login': remoteConfig.getBool('enable_biometric_login'),
        'enable_dark_mode': remoteConfig.getBool('enable_dark_mode'),
        'enable_push_notifications': remoteConfig.getBool('enable_push_notifications'),
        'enable_in_app_review': remoteConfig.getBool('enable_in_app_review'),
        'enable_analytics_dashboard': remoteConfig.getBool('enable_analytics_dashboard'),
        'maintenance_mode_active': remoteConfig.getBool('maintenance_mode_active'),
        'minimum_required_version': remoteConfig.getString('minimum_required_version'),
      };

      AppLogger.info(_tag, 'Remote config values loaded.');
    } catch (e, st) {
      // Recoverable: log and let the caller use FeatureFlagDefaults.
      AppLogger.warning(_tag, 'Remote config fetch failed — using defaults.', error: e, stackTrace: st);
      // ctx.remoteConfigValues stays null — step 6 handles this.
    }
  }

  Duration _resolveFetchInterval(dynamic flavor) {
    // Use the flavor's tag to determine interval without importing AppFlavor directly.
    final tag = FlavorConfig.instance.flavor.tag;
    return switch (tag) {
      'dev' => Duration.zero,
      'qa' => const Duration(hours: 1),
      'stg' => const Duration(hours: 1),
      _ => const Duration(hours: 12),
    };
  }
}
