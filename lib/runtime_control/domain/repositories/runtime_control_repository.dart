import 'package:flutter_production_kit/runtime_control/domain/entities/feature_flag.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/kill_switch.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';

/// Combined repository for runtime control — feature flags + config + kill switches.
///
/// Design rationale:
/// - Single interface for all runtime control data access.
/// - The domain layer should not depend on any specific storage mechanism.
/// - Data can come from remote config, local cache, or embedded defaults.
abstract class RuntimeControlRepository {
  const RuntimeControlRepository();

  // ── Feature Flags ──────────────────────────────────────────────────────────

  /// Get a specific feature flag by key.
  Future<FeatureFlag?> getFlag(String key);

  /// Get all feature flags.
  Future<Map<String, FeatureFlag>> getAllFlags();

  /// Update a feature flag.
  Future<void> updateFlag(FeatureFlag flag);

  /// Check if a flag exists.
  Future<bool> hasFlag(String key);

  // ── Runtime Config ─────────────────────────────────────────────────────────

  /// Get the current active config.
  Future<RuntimeConfig?> getActiveConfig();

  /// Get the last known good config (for fallback).
  Future<RuntimeConfig?> getLastKnownGoodConfig();

  /// Save a new config as active.
  Future<void> saveActiveConfig(RuntimeConfig config);

  /// Save a config as the last known good version.
  Future<void> saveLastKnownGoodConfig(RuntimeConfig config);

  /// Get a specific config version.
  Future<RuntimeConfig?> getConfigByVersion(int version);

  // ── Kill Switches ──────────────────────────────────────────────────────────

  /// Get kill switch state by key.
  Future<KillSwitch?> getKillSwitch(String key);

  /// Get all active kill switches.
  Future<List<KillSwitch>> getActiveKillSwitches();

  /// Update kill switch state.
  Future<void> updateKillSwitch(KillSwitch killSwitch);

  // ── Maintenance ────────────────────────────────────────────────────────────

  /// Clear all cached data.
  Future<void> clear();
}
