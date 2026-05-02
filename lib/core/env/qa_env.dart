import 'package:flutter_production_kit/core/env/base_env.dart';

/// QA environment configuration.
///
/// - Uses dedicated QA API server.
/// - Firebase uses the QA project.
/// - INFO-level logging (not verbose — keeps test logs readable).
/// - Crash reporting enabled (to catch issues before staging).
/// - Analytics disabled (avoids polluting prod analytics with test events).
/// - Feature flags configured for QA testing scenarios.
final class QaEnv extends BaseEnv {
  const QaEnv();

  @override
  String get appName => 'MyApp (QA)';

  @override
  String get bundleIdSuffix => '.qa';

  @override
  String get apiBaseUrl => 'https://qa-api.myapp-internal.example.com';

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 20000;

  @override
  FirebaseEnvConfig get firebase => const FirebaseEnvConfig(
        projectId: 'myapp-qa',
        appId: '1:111111111111:android:1111111111111111',
        apiKey: 'qa-firebase-api-key',
        messagingSenderId: '111111111111',
        storageBucket: 'myapp-qa.appspot.com',
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
  bool get prettyPrintLogs => false;
}
