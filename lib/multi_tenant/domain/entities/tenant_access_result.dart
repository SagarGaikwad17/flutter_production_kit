/// Tenant access result — explicit outcome of a tenant access check.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No bool-only checks — each result carries context.
/// - UI layer can pattern-match to show correct messaging.
/// - Audit layer can log the exact access decision.
///
/// Outcomes:
/// - TenantResolved: tenant context successfully resolved.
/// - AccessDeniedTenantMismatch: user's tenant doesn't match requested tenant.
/// - AccessDeniedTenantSuspended: tenant is suspended.
/// - AccessDeniedTenantExpired: tenant has expired.
/// - BranchScopeViolation: user doesn't have access to requested branch.
/// - BrandingIsolationEnforced: branding loaded for correct tenant.
/// - TenantSwitchRequiresRevalidation: tenant switch detected, revalidation needed.
/// - StaleTenantCacheInvalidated: cached tenant data was stale and invalidated.
sealed class TenantAccessResult {
  const TenantAccessResult({required this.tenantId});
  final String tenantId;

  bool get isSuccess => this is TenantResolved;
  bool get isDenied => !isSuccess;
}

/// Tenant context successfully resolved.
final class TenantResolved extends TenantAccessResult {
  const TenantResolved({
    required super.tenantId,
    required this.tenantSlug,
    required this.correlationId,
    this.branchId,
  });

  final String tenantSlug;
  final String correlationId;
  final String? branchId;
}

/// Access denied — user's tenant doesn't match requested tenant.
final class AccessDeniedTenantMismatch extends TenantAccessResult {
  const AccessDeniedTenantMismatch({
    required super.tenantId,
    required this.userTenantId,
    required this.requestedTenantId,
    this.userId,
  });

  final String userTenantId;
  final String requestedTenantId;
  final String? userId;
}

/// Access denied — tenant is suspended.
final class AccessDeniedTenantSuspended extends TenantAccessResult {
  const AccessDeniedTenantSuspended({
    required super.tenantId,
    required this.suspendedAt,
    this.reason,
  });

  final DateTime suspendedAt;
  final String? reason;
}

/// Access denied — tenant has expired.
final class AccessDeniedTenantExpired extends TenantAccessResult {
  const AccessDeniedTenantExpired({
    required super.tenantId,
    required this.expiredAt,
  });

  final DateTime expiredAt;
}

/// Branch scope violation — user doesn't have access to requested branch.
final class BranchScopeViolation extends TenantAccessResult {
  const BranchScopeViolation({
    required super.tenantId,
    required this.userBranchId,
    required this.requestedBranchId,
    this.userId,
  });

  final String userBranchId;
  final String requestedBranchId;
  final String? userId;
}

/// Branding isolation enforced — correct branding loaded.
final class BrandingIsolationEnforced extends TenantAccessResult {
  const BrandingIsolationEnforced({
    required super.tenantId,
    required this.brandingLoaded,
  });

  final bool brandingLoaded;
}

/// Tenant switch requires revalidation.
final class TenantSwitchRequiresRevalidation extends TenantAccessResult {
  const TenantSwitchRequiresRevalidation({
    required super.tenantId,
    required this.previousTenantId,
    required this.newTenantId,
    this.userId,
  });

  final String previousTenantId;
  final String newTenantId;
  final String? userId;
}

/// Stale tenant cache invalidated.
final class StaleTenantCacheInvalidated extends TenantAccessResult {
  const StaleTenantCacheInvalidated({
    required super.tenantId,
    required this.invalidatedAt,
    this.cachedTenantId,
  });

  final DateTime invalidatedAt;
  final String? cachedTenantId;
}
