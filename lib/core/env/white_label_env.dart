import 'package:flutter_production_kit/core/env/base_env.dart';
import 'package:flutter_production_kit/flavors/white_label/white_label_client.dart';

/// Parameterized white-label environment configuration.
///
/// Design rationale:
/// White-label clients share the same code but require different:
/// - API endpoints (some clients self-host)
/// - Firebase projects (regulatory/data isolation)
/// - Branding (logo, colors, name)
/// - Feature set (not all clients purchase all features)
///
/// Instead of duplicating env files for each client, [WhiteLabelEnv] is
/// parameterized by [WhiteLabelClient]. Client-specific values are
/// stored in [ClientAConfig] / [ClientBConfig] etc.
///
/// ADDING A NEW WHITE-LABEL CLIENT:
///   1. Add to [WhiteLabelClient] enum.
///   2. Create a config class (e.g., client_c_config.dart).
///   3. Add a switch case in this class.
///   4. Add [AppFlavor.whiteLabelClientC] and a main_white_label_client_c.dart.
final class WhiteLabelEnv extends BaseEnv {
  const WhiteLabelEnv({required this.client});

  final WhiteLabelClient client;

  @override
  String get appName => switch (client) {
        WhiteLabelClient.clientA => 'Client A App',
        WhiteLabelClient.clientB => 'Client B App',
      };

  @override
  String get bundleIdSuffix => '.${client.clientId}';

  @override
  String get apiBaseUrl => switch (client) {
        WhiteLabelClient.clientA => 'https://api.clienta.example.com',
        WhiteLabelClient.clientB => 'https://api.clientb.example.com',
      };

  @override
  String get apiVersionPath => '/v1';

  @override
  int get apiTimeoutMs => 10000;

  @override
  FirebaseEnvConfig get firebase => switch (client) {
        WhiteLabelClient.clientA => const FirebaseEnvConfig(
            projectId: 'clienta-prod',
            appId: '1:555555555555:android:5555555555555555',
            apiKey: 'client-a-firebase-api-key',
            messagingSenderId: '555555555555',
            storageBucket: 'clienta-prod.appspot.com',
          ),
        WhiteLabelClient.clientB => const FirebaseEnvConfig(
            projectId: 'clientb-prod',
            appId: '1:666666666666:android:6666666666666666',
            apiKey: 'client-b-firebase-api-key',
            messagingSenderId: '666666666666',
            storageBucket: 'clientb-prod.appspot.com',
          ),
      };

  @override
  FeatureFlagDefaults get featureFlagDefaults => switch (client) {
        WhiteLabelClient.clientA => const FeatureFlagDefaults(
            enableBiometricLogin: true,
            enableDarkMode: true,
            enablePushNotifications: true,
            maintenanceModeActive: false,
            minimumRequiredVersion: '1.0.0',
          ),
        WhiteLabelClient.clientB => const FeatureFlagDefaults(
            enableBiometricLogin: false,
            enableDarkMode: false,
            enablePushNotifications: true,
            maintenanceModeActive: false,
            minimumRequiredVersion: '1.0.0',
          ),
      };

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
