/// Tenant entity — represents an isolated organizational unit.
///
/// Design rationale:
/// - [id] is a UUID — globally unique and unguessable.
/// - [slug] is a human-readable identifier for URLs and display.
/// - [name] is the display name for the tenant.
/// - [tier] determines the tenant's feature entitlement level.
/// - [status] controls tenant lifecycle (active, suspended, pending, expired).
/// - [allowedBranches] defines the branch hierarchy scope.
/// - [compliancePolicies] defines tenant-specific compliance rules.
/// - [environment] isolates tenant data by environment (prod, staging, dev).
/// - [metadata] carries safe diagnostic data — NEVER sensitive info.
///
/// Tenant isolation is enforced at every layer:
/// - API requests include tenant ID in headers.
/// - Local storage keys are prefixed with tenant ID.
/// - Feature flags are scoped to tenant ID.
/// - Billing subscriptions are bound to tenant ID.
class TenantEntity {
  const TenantEntity({
    required this.id,
    required this.slug,
    required this.name,
    required this.tier,
    required this.status,
    required this.environment,
    this.allowedBranches = const [],
    this.compliancePolicies = const {},
    this.featureOverrides = const {},
    this.billingSubscriptionId,
    this.createdAt,
    this.activatedAt,
    this.expiresAt,
    this.metadata = const {},
  });

  final String id;
  final String slug;
  final String name;
  final TenantTier tier;
  final TenantStatus status;
  final TenantEnvironment environment;
  final List<String> allowedBranches;
  final Map<String, String> compliancePolicies;
  final Map<String, String> featureOverrides;
  final String? billingSubscriptionId;
  final DateTime? createdAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final Map<String, String> metadata;

  bool get isActive => status == TenantStatus.active;
  bool get isSuspended => status == TenantStatus.suspended;
  bool get isExpired {
    final expires = expiresAt;
    return expires != null && DateTime.now().isAfter(expires);
  }

  bool hasBranch(String branchId) {
    return allowedBranches.isEmpty || allowedBranches.contains(branchId);
  }

  String? getCompliancePolicy(String key) {
    return compliancePolicies[key];
  }

  String? getFeatureOverride(String featureKey) {
    return featureOverrides[featureKey];
  }
}

enum TenantTier {
  free,
  standard,
  professional,
  enterprise,
}

enum TenantStatus {
  pending,
  active,
  suspended,
  expired,
  archived,
}

enum TenantEnvironment {
  production,
  staging,
  development,
}
