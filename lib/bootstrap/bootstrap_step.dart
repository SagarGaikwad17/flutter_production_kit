/// Enumeration of all bootstrap steps.
///
/// Design rationale:
/// Named steps (not raw strings) prevent typos, enable exhaustive switches,
/// and allow [BootstrapTracer] to build structured timing reports.
///
/// The order here is the canonical execution order — do not reorder casually.
/// Each step may have dependencies on previous steps being complete.
enum BootstrapStep {
  // Step 1: Flavor and config must be valid before anything else runs.
  flavorInit(
    displayName: 'Flavor Initialization',
    isBlocking: true,
    timeoutMs: 2000,
  ),

  // Step 2: Secure storage init — needed by auth restore (step 7).
  secureStorageInit(
    displayName: 'Secure Storage Init',
    isBlocking: true,
    timeoutMs: 3000,
  ),

  // Step 3: Firebase — needed by crash reporting (step 4) and remote config (step 5).
  firebaseInit(
    displayName: 'Firebase Initialization',
    isBlocking: true,
    timeoutMs: 10000,
  ),

  // Step 4: Crash reporting — should be up before any step that can fail.
  crashReportingInit(
    displayName: 'Crash Reporting Init',
    isBlocking: false, // recoverable — app can run without Crashlytics
    timeoutMs: 5000,
  ),

  // Step 5: Remote config — must complete before feature flag preload.
  remoteConfigFetch(
    displayName: 'Remote Config Fetch',
    isBlocking: false, // recoverable — use FeatureFlagDefaults as fallback
    timeoutMs: 8000,
  ),

  // Step 6: Feature flags — must complete before app logic runs.
  featureFlagPreload(
    displayName: 'Feature Flag Preload',
    isBlocking: false, // recoverable — use FeatureFlagDefaults as fallback
    timeoutMs: 3000,
  ),

  // Step 7: Auth session restore — determines if user goes to home or login.
  authSessionRestore(
    displayName: 'Auth Session Restore',
    isBlocking: false, // recoverable — treat as logged out
    timeoutMs: 5000,
  ),

  // Step 8: Permissions — preload current status (do not request yet).
  permissionPreload(
    displayName: 'Permission State Preload',
    isBlocking: false,
    timeoutMs: 3000,
  ),

  // Step 9: Forced update check — must block if update is required.
  forcedUpdateCheck(
    displayName: 'Forced Update Check',
    isBlocking: true, // blocking only when update IS required
    timeoutMs: 5000,
  ),

  // Step 10: Maintenance mode — must block if active.
  maintenanceModeCheck(
    displayName: 'Maintenance Mode Check',
    isBlocking: true, // blocking only when maintenance IS active
    timeoutMs: 3000,
  ),

  // Step 11: Deep link — process any link that opened the app.
  deepLinkHandling(
    displayName: 'Deep Link Processing',
    isBlocking: false,
    timeoutMs: 3000,
  ),

  // Step 12: Notification payload — process notification that opened the app.
  notificationPayload(
    displayName: 'Notification Payload Handling',
    isBlocking: false,
    timeoutMs: 3000,
  ),

  // Step 13: Localization — preload locale before UI renders.
  localizationPreload(
    displayName: 'Localization Preload',
    isBlocking: false,
    timeoutMs: 3000,
  ),

  // Step 14: Final launch — build AppSession and hand off to runApp.
  finalLaunch(
    displayName: 'Final App Launch',
    isBlocking: true,
    timeoutMs: 2000,
  );

  const BootstrapStep({
    required this.displayName,
    required this.isBlocking,
    required this.timeoutMs,
  });

  /// Human-readable step name for logging and tracing.
  final String displayName;

  /// Whether failure of this step should stop the entire bootstrap chain.
  ///
  /// Note: even for non-blocking steps, the step result is still recorded
  /// and available in [AppSession.failedSteps].
  final bool isBlocking;

  /// Maximum time (ms) allowed for this step before a timeout error is raised.
  final int timeoutMs;

  Duration get timeout => Duration(milliseconds: timeoutMs);
}
