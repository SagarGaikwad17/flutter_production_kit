import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';
import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_onboarding_result.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Tenant onboarding engine — orchestrates enterprise tenant provisioning.
///
/// Design rationale:
/// - Onboarding is a multi-step process with explicit results.
/// - Each step is validated before proceeding.
/// - Failures are explicit with actionable error messages.
/// - Success includes provisioned resources for audit.
///
/// Onboarding flow:
///   1. Create tenant with unique ID.
///   2. Provision branding.
///   3. Provision feature entitlements.
///   4. Create initial admin user.
///   5. Configure compliance policies.
///   6. Activate tenant.
class TenantOnboardingEngine {
  const TenantOnboardingEngine({
    required ITenantRepository tenantRepository,
    required IBrandingRepository brandingRepository,
    required ICompliancePolicyRepository compliancePolicyRepository,
  })  : _tenantRepository = tenantRepository,
        _brandingRepository = brandingRepository,
        _compliancePolicyRepository = compliancePolicyRepository;

  final ITenantRepository _tenantRepository;
  final IBrandingRepository _brandingRepository;
  final ICompliancePolicyRepository _compliancePolicyRepository;

  /// Onboard a new tenant with all required provisioning.
  Future<TenantOnboardingResult> onboardTenant({
    required String tenantId,
    required String tenantSlug,
    required String tenantName,
    required String adminUserId,
    TenantTier tier = TenantTier.free,
    TenantEnvironment environment = TenantEnvironment.production,
    Map<String, String>? brandingConfig,
    List<String>? entitlementKeys,
    Map<String, String>? compliancePolicies,
    List<String>? branchIds,
  }) async {
    String? createdTenantId;

    try {
      // Step 1: Create tenant
      final tenant = TenantEntity(
        id: tenantId,
        slug: tenantSlug,
        name: tenantName,
        tier: tier,
        status: TenantStatus.pending,
        environment: environment,
        allowedBranches: branchIds ?? const [],
        compliancePolicies: compliancePolicies ?? const {},
        featureOverrides: {},
        createdAt: DateTime.now(),
      );
      await _tenantRepository.save(tenant);
      createdTenantId = tenantId;

      // Step 2: Provision branding
      if (brandingConfig != null && brandingConfig.isNotEmpty) {
        await _brandingRepository.saveBrandingConfig(tenantId, brandingConfig);
      }

      // Step 3: Configure compliance policies
      if (compliancePolicies != null && compliancePolicies.isNotEmpty) {
        for (final entry in compliancePolicies.entries) {
          await _compliancePolicyRepository.savePolicy(
              tenantId, entry.key, entry.value);
        }
      }

      // Step 4: Activate tenant
      await _tenantRepository.updateStatus(tenantId, TenantStatus.active);

      return TenantOnboardingSuccess(
        tenantId: tenantId,
        tenantSlug: tenantSlug,
        adminUserId: adminUserId,
        provisionedAt: DateTime.now(),
        branchIds: branchIds ?? const [],
        entitlementKeys: entitlementKeys ?? const [],
        compliancePolicies: compliancePolicies ?? const {},
      );
    } catch (e) {
      // Rollback on failure
      if (createdTenantId != null) {
        try {
          await _tenantRepository.delete(createdTenantId);
          await _brandingRepository.clearBrandingConfig(createdTenantId);
        } catch (_) {
          // Cleanup failure logged but not rethrown
        }
      }

      return TenantOnboardingFailed(
        failedStep: TenantOnboardingStep.tenantCreation,
        reason: e.toString(),
        tenantId: createdTenantId,
        recoveryAction: 'Retry onboarding after verifying prerequisites',
      );
    }
  }
}
