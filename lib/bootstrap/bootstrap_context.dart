import 'package:flutter_production_kit/bootstrap/bootstrap_step.dart';
import 'package:flutter_production_kit/core/logging/bootstrap_tracer.dart';

/// Mutable context object threaded through the bootstrap chain.
///
/// Design rationale:
/// Each step reads from and writes to [BootstrapContext].
/// This eliminates the need for global state or static variables during startup.
/// The context is owned by [AppBootstrap] and discarded after bootstrap completes.
class BootstrapContext {
  BootstrapContext({required this.tracer});

  final BootstrapTracer tracer;

  // ── Step Outputs — Written by steps, read by later steps ──────────────────

  /// Set by [SecureStorageInitStep].
  bool secureStorageReady = false;

  /// Set by [FirebaseInitStep].
  bool firebaseReady = false;

  /// Set by [CrashReportingInitStep].
  bool crashReportingReady = false;

  /// Set by [RemoteConfigFetchStep]. Null = not fetched yet.
  Map<String, dynamic>? remoteConfigValues;

  /// Set by [FeatureFlagPreloadStep].
  bool? enableNewOnboarding;
  bool? enableBiometricLogin;
  bool? enableDarkMode;
  bool? enablePushNotifications;
  bool? enableInAppReview;
  bool? enableAnalyticsDashboard;

  /// Set by [AuthSessionRestoreStep].
  bool isAuthenticated = false;

  /// Set by [DeepLinkHandlingStep].
  String? initialDeepLink;

  /// Set by [NotificationPayloadStep].
  Map<String, dynamic>? initialNotificationPayload;

  /// Set by [LocalizationPreloadStep].
  String locale = 'en';

  /// Non-blocking steps that failed — accumulated during the chain.
  final List<BootstrapStep> failedSteps = [];

  void recordFailedStep(BootstrapStep step) {
    if (!failedSteps.contains(step)) failedSteps.add(step);
  }
}
