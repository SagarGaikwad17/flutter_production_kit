import 'package:flutter_production_kit/bootstrap/bootstrap_step.dart';

/// Sealed result type for the entire bootstrap sequence.
///
/// Design rationale:
/// Using a sealed class forces every call-site (the App widget) to handle
/// all three outcomes at compile time — no silent unhandled failures.
///
/// [BootstrapSuccess]: All blocking steps passed. App is fully initialized.
///   Non-blocking failures are recorded in [AppSession.failedSteps] but
///   the app continues.
///
/// [BootstrapRecoverableFailure]: A non-blocking step failed but the app can
///   still launch in a degraded state. The UI should show a non-blocking
///   warning (e.g., "Remote config unavailable — using defaults").
///   This should NEVER prevent the user from using the app.
///
/// [BootstrapBlockingFailure]: A blocking condition was detected. The app
///   MUST NOT proceed. Show a hard-stop screen (maintenance, forced update, etc.)
sealed class BootstrapResult {
  const BootstrapResult();
}

final class BootstrapSuccess extends BootstrapResult {
  const BootstrapSuccess({required this.session});

  final AppSession session;
}

final class BootstrapRecoverableFailure extends BootstrapResult {
  const BootstrapRecoverableFailure({
    required this.reason,
    required this.failedStep,
    required this.session,
  });

  final String reason;
  final BootstrapStep failedStep;

  /// The app session, built from available data. May be partial.
  final AppSession session;
}

final class BootstrapBlockingFailure extends BootstrapResult {
  const BootstrapBlockingFailure({
    required this.reason,
    required this.failedStep,
    this.cause,
  });

  final AppBlockingReason reason;
  final BootstrapStep failedStep;
  final Object? cause;
}

// ── Blocking Reason Enum ─────────────────────────────────────────────────────

/// Identifies WHY the bootstrap was blocked.
///
/// The [App] widget switches on this to show the correct hard-stop screen.
enum AppBlockingReason {
  /// User must update the app before continuing.
  forcedUpdate,

  /// App is in maintenance mode — no access right now.
  maintenanceMode,

  /// Firebase security check failed — potential tamper or misconfiguration.
  firebaseSecurityFailure,

  /// Flavor misconfiguration — only possible in dev/CI scenarios.
  flavorMismatch,

  /// Secure storage is corrupted or inaccessible — device-level issue.
  secureStorageFailure,

  /// An unexpected unrecoverable error occurred during bootstrap.
  unknown,
}

// ── App Session ──────────────────────────────────────────────────────────────

/// The result of a successful (or partially successful) bootstrap.
///
/// This is the handoff object from bootstrap → app.
/// It carries all state that the bootstrap gathered.
class AppSession {
  const AppSession({
    required this.isAuthenticated,
    required this.featureFlags,
    required this.locale,
    this.initialDeepLink,
    this.initialNotificationPayload,
    this.failedSteps = const [],
  });

  /// Whether an existing auth session was restored.
  final bool isAuthenticated;

  /// Resolved feature flags (remote config + defaults merged).
  final ResolvedFeatureFlags featureFlags;

  /// Resolved locale for the app.
  final String locale;

  /// Deep link that triggered app launch, if any.
  final String? initialDeepLink;

  /// Notification payload that triggered app launch, if any.
  final Map<String, dynamic>? initialNotificationPayload;

  /// Non-blocking steps that failed during bootstrap.
  /// The app continues but these are available for diagnostics.
  final List<BootstrapStep> failedSteps;

  bool get hasDegradedState => failedSteps.isNotEmpty;
}

// ── Resolved Feature Flags ───────────────────────────────────────────────────

/// Feature flags resolved from Firebase Remote Config with env defaults fallback.
class ResolvedFeatureFlags {
  const ResolvedFeatureFlags({
    required this.enableNewOnboarding,
    required this.enableBiometricLogin,
    required this.enableDarkMode,
    required this.enablePushNotifications,
    required this.enableInAppReview,
    required this.enableAnalyticsDashboard,
  });

  /// Creates flags from the env default values.
  /// Used as fallback when remote config is unavailable.
  factory ResolvedFeatureFlags.fromDefaults(dynamic defaults) {
    return const ResolvedFeatureFlags(
      enableNewOnboarding: false,
      enableBiometricLogin: false,
      enableDarkMode: true,
      enablePushNotifications: false,
      enableInAppReview: false,
      enableAnalyticsDashboard: false,
    );
  }

  final bool enableNewOnboarding;
  final bool enableBiometricLogin;
  final bool enableDarkMode;
  final bool enablePushNotifications;
  final bool enableInAppReview;
  final bool enableAnalyticsDashboard;
}
