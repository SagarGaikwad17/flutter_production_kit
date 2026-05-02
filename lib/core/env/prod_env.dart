import 'package:flutter_production_kit/core/env/base_env.dart';

/// Production environment configuration.
///
/// CRITICAL RULES:
/// - This class must NEVER be instantiated in a debug build.
///   [FlavorConfig.initialize] and [FlavorValidator] enforce this at runtime.
/// - API URL must be HTTPS. [FlavorValidator] enforces this.
/// - Logging level is WARNING or above only — no debug info in prod logs.
/// - All observability enabled.
/// - Feature flags are conservative (controlled via Firebase Remote Config).
final class ProdEnv extends BaseEnv {
  const ProdEnv();

  @override
  String get appName => 'MyApp';

  @override
  String get bundleIdSuffix => '';

  @override
  String get apiBaseUrl => 'https://api.myapp.example.com';

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 10000;

  @override
  FirebaseEnvConfig get firebase => const FirebaseEnvConfig(
        projectId: 'myapp-prod',
        appId: '1:333333333333:android:3333333333333333',
        apiKey: 'prod-firebase-api-key',
        messagingSenderId: '333333333333',
        storageBucket: 'myapp-prod.appspot.com',
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
