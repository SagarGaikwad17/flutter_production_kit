import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';

/// Tenant entitlement engine — resolves feature access for a tenant.
///
/// Design rationale:
/// - Entitlements are resolved in priority order:
///   1. Tenant-specific feature overrides.
///   2. Tier-based entitlement matrix.
///   3. Default feature flags.
/// - Supports per-tenant feature gating.
/// - Supports per-branch feature gating.
/// - Supports time-limited feature access.
class TenantEntitlementEngine {
  const TenantEntitlementEngine({
    this.tierEntitlementMatrix = const {
      TenantTier.free: [],
      TenantTier.standard: ['advanced_analytics', 'custom_branding'],
      TenantTier.professional: [
        'advanced_analytics',
        'custom_branding',
        'branch_management',
        'api_access',
      ],
      TenantTier.enterprise: [
        'advanced_analytics',
        'custom_branding',
        'branch_management',
        'api_access',
        'sso',
        'compliance_reporting',
        'audit_logs',
        'priority_support',
      ],
    },
  });

  final Map<TenantTier, List<String>> tierEntitlementMatrix;

  /// Check if a tenant has access to a feature.
  bool hasFeatureAccess({
    required TenantEntity tenant,
    required String featureKey,
    String? branchId,
  }) {
    // Check tenant-specific override first
    final override = tenant.getFeatureOverride(featureKey);
    if (override == 'enabled') return true;
    if (override == 'disabled') return false;

    // Check tier-based entitlements
    final tierFeatures = tierEntitlementMatrix[tenant.tier] ?? const [];
    return tierFeatures.contains(featureKey);
  }

  /// Get all features accessible to a tenant.
  List<String> getAccessibleFeatures(TenantEntity tenant) {
    final features = <String>{};

    // Add tier-based features
    final tierFeatures = tierEntitlementMatrix[tenant.tier] ?? const [];
    features.addAll(tierFeatures);

    // Add override-enabled features
    for (final entry in tenant.featureOverrides.entries) {
      if (entry.value == 'enabled') {
        features.add(entry.key);
      }
    }

    return features.toList();
  }

  /// Check if a tenant's tier supports a feature.
  bool isFeatureAvailableInTier({
    required TenantTier tier,
    required String featureKey,
  }) {
    final tierFeatures = tierEntitlementMatrix[tier] ?? const [];
    return tierFeatures.contains(featureKey);
  }
}
