import 'package:flutter_production_kit/core/env/base_env.dart';

/// Staging environment configuration.
///
/// - Mirror of production infrastructure with production Firebase project
///   (separate staging project, same infra tier).
/// - Warning-level logging only (matches production logging behavior).
/// - Analytics enabled (to validate tracking before prod release).
/// - Crash reporting enabled.
/// - Feature flags conservative (same defaults as prod).
final class StagingEnv extends BaseEnv {
  const StagingEnv();

  @override
  String get appName => 'MyApp (Staging)';

  @override
  String get bundleIdSuffix => '.staging';

  @override
  String get apiBaseUrl => 'https://staging-api.myapp.example.com';

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 15000;

  @override
  FirebaseEnvConfig get firebase => const FirebaseEnvConfig(
        projectId: 'myapp-staging',
        appId: '1:222222222222:android:2222222222222222',
        apiKey: 'staging-firebase-api-key',
        messagingSenderId: '222222222222',
        storageBucket: 'myapp-staging.appspot.com',
      );

  @override
  FeatureFlagDefaults get featureFlagDefaults => const FeatureFlagDefaults(
        enableNewOnboarding: false,
        enableBiometricLogin: false,
        enableDarkMode: true,
        enablePushNotifications: false,
        enableInAppReview: false,
        enableAnalyticsDashboard: false,
        maintenanceModeActive: false,
        minimumRequiredVersion: '1.0.0',
      );

  @override
  bool get analyticsEnabled => true;

  @override
  bool get crashReportingEnabled => true;

  @override
  bool get sentryEnabled => false;

  @override
  String get sentryDsn => '';

  @override
  AppLogLevel get minimumLogLevel => AppLogLevel.warning;

  @override
  bool get prettyPrintLogs => false;
}
