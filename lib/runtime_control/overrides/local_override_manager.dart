import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/exceptions/runtime_control_exception.dart';

/// Local override manager — secure local feature flag overrides for dev/QA.
///
/// Design rationale:
/// - Allows developers and QA to override feature flags locally for testing.
/// - Overrides are stored in memory — NOT persisted across app restarts.
/// - Overrides are REJECTED in production builds unless explicitly enabled.
/// - [isProductionMode] controls whether overrides are allowed.
/// - [allowProductionOverrides] must be explicitly set to true to enable
///   overrides in production (for emergency debugging — use with caution).
/// - All override usage is logged for audit purposes.
///
/// Security model:
/// - Dev/QA: overrides allowed freely.
/// - Production: overrides rejected by default.
/// - Emergency: overrides allowed with explicit flag + audit logging.
class LocalOverrideManager {
  LocalOverrideManager({
    this.isProductionMode = true,
    this.allowProductionOverrides = false,
  });

  static const String _tag = 'LocalOverrideManager';

  final bool isProductionMode;
  final bool allowProductionOverrides;

  final Map<String, LocalOverride> _overrides = {};

  /// Set a local override for a feature flag.
  void setOverride({
    required String featureKey,
    required bool enabled,
    String? reason,
  }) {
    if (isProductionMode && !allowProductionOverrides) {
      throw LocalOverrideRejectedException(
        message: 'Local overrides are not allowed in production mode.',
        featureKey: featureKey,
      );
    }

    _overrides[featureKey] = LocalOverride(
      featureKey: featureKey,
      enabled: enabled,
      reason: reason ?? 'Local override for testing.',
      setAt: DateTime.now(),
    );

    AppLogger.warning(
      _tag,
      'Local override SET: $featureKey = $enabled '
      '(production: $isProductionMode, reason: $reason)',
    );
  }

  /// Get a local override for a feature flag.
  LocalOverride? getOverride(String featureKey) {
    return _overrides[featureKey];
  }

  /// Remove a local override.
  void removeOverride(String featureKey) {
    _overrides.remove(featureKey);
    AppLogger.info(_tag, 'Local override removed: $featureKey');
  }

  /// Clear all local overrides.
  void clearOverrides() {
    _overrides.clear();
    AppLogger.info(_tag, 'All local overrides cleared.');
  }

  /// Get all active overrides.
  Map<String, LocalOverride> get allOverrides => Map.unmodifiable(_overrides);

  /// Check if overrides are enabled.
  bool get areOverridesEnabled {
    if (!isProductionMode) return true;
    return allowProductionOverrides;
  }
}

/// Local override entry.
class LocalOverride {
  const LocalOverride({
    required this.featureKey,
    required this.enabled,
    required this.reason,
    required this.setAt,
  });

  final String featureKey;
  final bool enabled;
  final String reason;
  final DateTime setAt;
}
