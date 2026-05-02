import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Feature mapping engine — maps entitlement keys to feature flags and policies.
///
/// Design rationale:
/// - Entitlement keys (e.g., "advanced_analytics") map to:
///   - Feature flag keys (for runtime control).
///   - Policy keys (for permission engine).
///   - UI feature keys (for frontend gating).
/// - Supports kill switches — instantly disable any feature regardless of plan.
/// - Supports overrides — grant features outside of plan entitlements.
/// - Cache-friendly — mappings are loaded once and reused.
class FeatureMappingEngine {
  FeatureMappingEngine({
    Map<String, FeatureMapping>? initialMappings,
    Set<String>? killedFeatures,
  })  : _mappings = initialMappings ?? {},
        _killedFeatures = killedFeatures ?? {};

  static const String _tag = 'FeatureMappingEngine';

  final Map<String, FeatureMapping> _mappings;
  final Set<String> _killedFeatures;

  /// Register a feature mapping.
  void registerMapping(String entitlementKey, FeatureMapping mapping) {
    _mappings[entitlementKey] = mapping;
    AppLogger.debug(_tag, 'Mapped: $entitlementKey → ${mapping.featureFlagKey}');
  }

  /// Kill a feature (runtime kill switch).
  void killFeature(String entitlementKey) {
    _killedFeatures.add(entitlementKey);
    AppLogger.warning(_tag, 'Feature killed: $entitlementKey');
  }

  /// Revive a killed feature.
  void reviveFeature(String entitlementKey) {
    _killedFeatures.remove(entitlementKey);
    AppLogger.info(_tag, 'Feature revived: $entitlementKey');
  }

  /// Check if a feature is killed.
  bool isFeatureKilled(String entitlementKey) {
    return _killedFeatures.contains(entitlementKey);
  }

  /// Get the feature flag key for an entitlement.
  String? getFeatureFlagKey(String entitlementKey) {
    return _mappings[entitlementKey]?.featureFlagKey;
  }

  /// Get the policy key for an entitlement.
  String? getPolicyKey(String entitlementKey) {
    return _mappings[entitlementKey]?.policyKey;
  }

  /// Get all entitlement keys for a plan tier.
  List<String> getEntitlementsForTier(PlanTier tier) {
    return _mappings.entries
        .where((e) => e.value.minimumTier.index <= tier.index)
        .map((e) => e.key)
        .toList();
  }

  /// Get all registered mappings.
  Map<String, FeatureMapping> getAllMappings() {
    return Map.unmodifiable(_mappings);
  }

  /// Clear all killed features.
  void clearKilledFeatures() {
    _killedFeatures.clear();
  }
}

/// Feature mapping — links an entitlement to runtime controls.
class FeatureMapping {
  const FeatureMapping({
    required this.featureFlagKey,
    required this.minimumTier,
    this.policyKey,
    this.uiFeatureKey,
    this.description,
    this.isKillable = true,
  });

  final String featureFlagKey;
  final PlanTier minimumTier;
  final String? policyKey;
  final String? uiFeatureKey;
  final String? description;
  final bool isKillable;
}
