/// Tenant onboarding result — outcome of enterprise tenant provisioning.
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
sealed class TenantOnboardingResult {
  const TenantOnboardingResult();

  bool get isSuccess => this is TenantOnboardingSuccess;
}

/// Onboarding completed successfully.
final class TenantOnboardingSuccess extends TenantOnboardingResult {
  const TenantOnboardingSuccess({
    required this.tenantId,
    required this.tenantSlug,
    required this.adminUserId,
    required this.provisionedAt,
    this.branchIds = const [],
    this.entitlementKeys = const [],
    this.compliancePolicies = const {},
  });

  final String tenantId;
  final String tenantSlug;
  final String adminUserId;
  final DateTime provisionedAt;
  final List<String> branchIds;
  final List<String> entitlementKeys;
  final Map<String, String> compliancePolicies;
}

/// Onboarding failed at a specific step.
final class TenantOnboardingFailed extends TenantOnboardingResult {
  const TenantOnboardingFailed({
    required this.failedStep,
    required this.reason,
    this.tenantId,
    this.recoveryAction,
  });

  final TenantOnboardingStep failedStep;
  final String reason;
  final String? tenantId;
  final String? recoveryAction;
}

/// Onboarding requires manual approval.
final class TenantOnboardingPendingApproval extends TenantOnboardingResult {
  const TenantOnboardingPendingApproval({
    required this.tenantId,
    required this.tenantSlug,
    required this.pendingApprovalStep,
    this.approverRole,
  });

  final String tenantId;
  final String tenantSlug;
  final TenantOnboardingStep pendingApprovalStep;
  final String? approverRole;
}

enum TenantOnboardingStep {
  tenantCreation,
  brandingProvisioning,
  entitlementProvisioning,
  adminUserCreation,
  branchSetup,
  complianceConfiguration,
  activation,
}
