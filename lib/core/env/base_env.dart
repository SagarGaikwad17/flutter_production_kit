/// Abstract base class for all environment configurations.
///
/// Design rationale:
/// - All fields are required non-nullable — there is no "optional" config.
///   Partial config is the enemy of production safety.
/// - Concrete env classes are const — zero runtime cost and IDE-visible.
/// - Firebase config is a nested class to make the grouping explicit and
///   prevent accidentally mixing project IDs with other string fields.
/// - FeatureFlagDefaults provides fallback values used when remote config
///   is unavailable (network error, timeout). This prevents feature flags
///   from defaulting to `false` (disabled) in ways that break the UX.
///
/// ADDING A NEW CONFIG FIELD:
///   1. Add to [BaseEnv] (required, non-nullable).
///   2. The Dart analyzer will show errors in every env class — fix them all.
///   3. Update bootstrap steps if the new field affects startup.
abstract class BaseEnv {
  const BaseEnv();

  // ── App Identity ─────────────────────────────────────────────────────────────

  /// App display name for this flavor.
  String get appName;

  /// Bundle ID suffix for this flavor (e.g., '.dev', '.qa', '' for prod).
  String get bundleIdSuffix;

  // ── Network ──────────────────────────────────────────────────────────────────

  /// Base URL for all API calls. Must be a valid HTTPS URL in production.
  String get apiBaseUrl;

  /// API version path prefix (e.g., '/v1', '/v2').
  String get apiVersionPath;

  /// Connection timeout in milliseconds.
  int get apiTimeoutMs;

  // ── Firebase ─────────────────────────────────────────────────────────────────

  /// Firebase project configuration for this flavor.
  FirebaseEnvConfig get firebase;

  // ── Feature Flags ─────────────────────────────────────────────────────────────

  /// Default feature flag values used when remote config is unavailable.
  ///
  /// Remote config should OVERRIDE these at runtime.
  /// These are conservative fallbacks, not the intended production values.
  FeatureFlagDefaults get featureFlagDefaults;

  // ── Observability ─────────────────────────────────────────────────────────────

  /// Whether analytics events should be sent.
  bool get analyticsEnabled;

  /// Whether crash reports should be submitted.
  bool get crashReportingEnabled;

  /// Whether Sentry should be enabled (in addition to Crashlytics).
  bool get sentryEnabled;

  /// Sentry DSN. Only required when [sentryEnabled] is true.
  String get sentryDsn;

  // ── Logging ──────────────────────────────────────────────────────────────────

  /// Minimum log level for this flavor.
  /// See [LogLevelPolicy] for how this is consumed.
  AppLogLevel get minimumLogLevel;

  /// Whether to pretty-print logs (with color/formatting). Dev only.
  bool get prettyPrintLogs;
}

// ── Firebase Config ──────────────────────────────────────────────────────────

/// Firebase project configuration.
///
/// These values come from google-services.json / GoogleService-Info.plist.
/// They are duplicated here to allow runtime cross-validation against the
/// actual Firebase SDK initialization — catching wrong-project scenarios.
class FirebaseEnvConfig {
  const FirebaseEnvConfig({
    required this.projectId,
    required this.appId,
    required this.apiKey,
    required this.messagingSenderId,
    required this.storageBucket,
  });

  final String projectId;
  final String appId;
  final String apiKey;
  final String messagingSenderId;
  final String storageBucket;

  @override
  String toString() => 'FirebaseEnvConfig(projectId: $projectId)';
}

// ── Feature Flag Defaults ─────────────────────────────────────────────────────

/// Default feature flag values.
///
/// Extend this class as new flags are added.
/// All flags default to the SAFE value (usually false/disabled).
class FeatureFlagDefaults {
  const FeatureFlagDefaults({
    this.enableNewOnboarding = false,
    this.enableBiometricLogin = false,
    this.enableDarkMode = true,
    this.enablePushNotifications = false,
    this.enableInAppReview = false,
    this.enableAnalyticsDashboard = false,
    this.maintenanceModeActive = false,
    this.minimumRequiredVersion = '1.0.0',
  });

  final bool enableNewOnboarding;
  final bool enableBiometricLogin;
  final bool enableDarkMode;
  final bool enablePushNotifications;
  final bool enableInAppReview;
  final bool enableAnalyticsDashboard;
  final bool maintenanceModeActive;
  final String minimumRequiredVersion;

  @override
  String toString() => 'FeatureFlagDefaults('
      'maintenance: $maintenanceModeActive, '
      'minVersion: $minimumRequiredVersion)';
}

// ── Log Level ────────────────────────────────────────────────────────────────

/// Application-level log levels.
///
/// Maps to the `logger` package's Level enum in [LogLevelPolicy].
enum AppLogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
  nothing,
}
