/// Enterprise flavor system.
///
/// Design rationale:
/// - Strongly typed enum — no String comparison anywhere in the codebase.
/// - [isProduction] drives logging, analytics, and crash reporting decisions.
/// - [supportsDebugTools] guards in-app developer menus, network inspector, etc.
/// - [isWhiteLabel] identifies white-label builds for branding resolution.
/// - [allowsDevOverrides] lets QA/staging builds override certain settings
///   (e.g., forcing a specific remote config value) without production risk.
///
/// ADDING A NEW FLAVOR:
///   1. Add enum value here.
///   2. Add entry in FlavorConfig.fromFlavor() in flavor_config.dart.
///   3. Add a BaseEnv implementation in lib/core/env/.
///   4. Create a main_<flavor>.dart entry point.
///   5. Add platform runner config (Gradle product flavor / Xcode scheme).
library;

enum AppFlavor {
  dev,
  qa,
  staging,
  prod,
  demo,
  whiteLabelClientA,
  whiteLabelClientB;

  // ── Identity ────────────────────────────────────────────────────────────────

  /// Human-readable label shown in debug banners and logs.
  String get displayName => switch (this) {
        AppFlavor.dev => 'Development',
        AppFlavor.qa => 'QA',
        AppFlavor.staging => 'Staging',
        AppFlavor.prod => 'Production',
        AppFlavor.demo => 'Demo',
        AppFlavor.whiteLabelClientA => 'Client A',
        AppFlavor.whiteLabelClientB => 'Client B',
      };

  /// Short tag used in log prefixes and analytics event properties.
  String get tag => switch (this) {
        AppFlavor.dev => 'dev',
        AppFlavor.qa => 'qa',
        AppFlavor.staging => 'stg',
        AppFlavor.prod => 'prod',
        AppFlavor.demo => 'demo',
        AppFlavor.whiteLabelClientA => 'wl_a',
        AppFlavor.whiteLabelClientB => 'wl_b',
      };

  // ── Production Safety Flags ─────────────────────────────────────────────────

  /// True for flavors that must NEVER run in Flutter debug mode.
  /// FlavorValidator enforces this at startup.
  bool get isProduction => switch (this) {
        AppFlavor.prod => true,
        AppFlavor.whiteLabelClientA => true,
        AppFlavor.whiteLabelClientB => true,
        _ => false,
      };

  /// True for flavors where debug-only tooling (Inspector, DevMenu) is allowed.
  bool get supportsDebugTools => switch (this) {
        AppFlavor.dev => true,
        AppFlavor.qa => true,
        AppFlavor.demo => true,
        _ => false,
      };

  /// True for white-label flavors — triggers client-specific branding resolution.
  bool get isWhiteLabel => switch (this) {
        AppFlavor.whiteLabelClientA => true,
        AppFlavor.whiteLabelClientB => true,
        _ => false,
      };

  /// True for flavors where QA/test overrides are permitted.
  bool get allowsDevOverrides => switch (this) {
        AppFlavor.dev => true,
        AppFlavor.qa => true,
        _ => false,
      };

  /// True if this flavor should send real analytics events.
  bool get analyticsEnabled => switch (this) {
        AppFlavor.prod => true,
        AppFlavor.staging => true,
        AppFlavor.whiteLabelClientA => true,
        AppFlavor.whiteLabelClientB => true,
        _ => false,
      };

  /// True if crash reports should be submitted to Crashlytics.
  bool get crashReportingEnabled => switch (this) {
        AppFlavor.prod => true,
        AppFlavor.staging => true,
        AppFlavor.whiteLabelClientA => true,
        AppFlavor.whiteLabelClientB => true,
        _ => false,
      };
}
