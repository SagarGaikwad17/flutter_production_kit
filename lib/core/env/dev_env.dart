import 'package:flutter_production_kit/core/env/base_env.dart';

/// Development environment configuration.
///
/// - Uses localhost API (or a mock server).
/// - Firebase uses the dedicated dev project.
/// - Full verbose logging enabled.
/// - Crash reporting disabled (no noise in dev dashboards).
/// - All feature flags enabled for testing.
final class DevEnv extends BaseEnv {
  const DevEnv();

  @override
  String get appName => 'MyApp (Dev)';

  @override
  String get bundleIdSuffix => '.dev';

  @override
  String get apiBaseUrl => 'http://localhost:8080';

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 30000;

  @override
  FirebaseEnvConfig get firebase => const FirebaseEnvConfig(
        projectId: 'myapp-dev',
        appId: '1:000000000000:android:0000000000000000',
        apiKey: 'dev-firebase-api-key',
        messagingSenderId: '000000000000',
        storageBucket: 'myapp-dev.appspot.com',
      );

  @override
  FeatureFlagDefaults get featureFlagDefaults => const FeatureFlagDefaults(
        enableNewOnboarding: true,
        enableBiometricLogin: true,
        enableDarkMode: true,
        enablePushNotifications: true,
        enableInAppReview: false,
        enableAnalyticsDashboard: true,
        maintenanceModeActive: false,
        minimumRequiredVersion: '0.0.1',
      );

  @override
  bool get analyticsEnabled => false;

  @override
  bool get crashReportingEnabled => false;

  @override
  bool get sentryEnabled => false;

  @override
  String get sentryDsn => '';

  @override
  AppLogLevel get minimumLogLevel => AppLogLevel.verbose;

  @override
  bool get prettyPrintLogs => true;
}
