import 'package:flutter_production_kit/core/env/base_env.dart';

/// Demo environment configuration.
///
/// Used for app store demos, sales demos, and conference presentations.
/// - Uses a dedicated demo API with seeded/mock data.
/// - Firebase project is isolated from prod.
/// - Debug tools enabled (for showing features to prospects).
/// - Crash reporting enabled (to catch demo-blocker bugs).
/// - All feature flags enabled (to showcase full feature set).
final class DemoEnv extends BaseEnv {
  const DemoEnv();

  @override
  String get appName => 'MyApp Demo';

  @override
  String get bundleIdSuffix => '.demo';

  @override
  String get apiBaseUrl => 'https://demo-api.myapp.example.com';

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 15000;

  @override
  FirebaseEnvConfig get firebase => const FirebaseEnvConfig(
        projectId: 'myapp-demo',
        appId: '1:444444444444:android:4444444444444444',
        apiKey: 'demo-firebase-api-key',
        messagingSenderId: '444444444444',
        storageBucket: 'myapp-demo.appspot.com',
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
  bool get crashReportingEnabled => true;

  @override
  bool get sentryEnabled => false;

  @override
  String get sentryDsn => '';

  @override
  AppLogLevel get minimumLogLevel => AppLogLevel.info;

  @override
  bool get prettyPrintLogs => true;
}
