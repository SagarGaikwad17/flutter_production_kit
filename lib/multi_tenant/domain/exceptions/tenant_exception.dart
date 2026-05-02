/// Multi-tenant exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific tenant isolation failure mode.
/// - [TenantException] is the base for all tenant errors.
/// - [IsolationException] covers cross-tenant isolation failures.
/// - [BranchException] covers branch scope failures.
/// - [BrandingException] covers white-label branding failures.
/// - [OnboardingException] covers tenant provisioning failures.
/// - NO sensitive data in exception messages.
sealed class TenantException implements Exception {
  const TenantException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'TenantException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Tenant not found.
final class TenantNotFoundException extends TenantException {
  const TenantNotFoundException({
    required super.message,
    this.tenantId,
    this.tenantSlug,
  });
  final String? tenantId;
  final String? tenantSlug;
}

/// Cross-tenant data access detected — critical isolation failure.
final class CrossTenantDataLeakException extends TenantException {
  const CrossTenantDataLeakException({
    required super.message,
    required this.userTenantId,
    required this.accessedTenantId,
    this.resourceType,
    this.resourceId,
    this.userId,
  });
  final String userTenantId;
  final String accessedTenantId;
  final String? resourceType;
  final String? resourceId;
  final String? userId;
}

/// Tenant context not resolved.
final class TenantContextNotResolvedException extends TenantException {
  const TenantContextNotResolvedException({
    required super.message,
    this.userId,
  });
  final String? userId;
}

/// Tenant context expired or invalid.
final class TenantContextExpiredException extends TenantException {
  const TenantContextExpiredException({
    required super.message,
    this.tenantId,
    this.expiredAt,
  });
  final String? tenantId;
  final DateTime? expiredAt;
}

/// Branch not found within tenant.
final class BranchNotFoundException extends TenantException {
  const BranchNotFoundException({
    required super.message,
    this.branchId,
    this.tenantId,
  });
  final String? branchId;
  final String? tenantId;
}

/// Branch scope violation — user accessing unauthorized branch.
final class BranchScopeViolationException extends TenantException {
  const BranchScopeViolationException({
    required super.message,
    required this.userBranchId,
    required this.requestedBranchId,
    this.userId,
    this.tenantId,
  });
  final String userBranchId;
  final String requestedBranchId;
  final String? userId;
  final String? tenantId;
}

/// Branding not found for tenant.
final class BrandingNotFoundException extends TenantException {
  const BrandingNotFoundException({
    required super.message,
    this.tenantId,
  });
  final String? tenantId;
}

/// Branding mismatch detected — wrong branding loaded.
final class BrandingMismatchException extends TenantException {
  const BrandingMismatchException({
    required super.message,
    required this.expectedTenantId,
    required this.loadedTenantId,
  });
  final String expectedTenantId;
  final String loadedTenantId;
}

/// Tenant onboarding failed.
final class TenantOnboardingFailedException extends TenantException {
  const TenantOnboardingFailedException({
    required super.message,
    this.tenantId,
    this.failedStep,
    this.recoveryAction,
  });
  final String? tenantId;
  final String? failedStep;
  final String? recoveryAction;
}

/// Tenant switch without revalidation.
final class TenantSwitchWithoutRevalidationException extends TenantException {
  const TenantSwitchWithoutRevalidationException({
    required super.message,
    required this.previousTenantId,
    required this.newTenantId,
    this.userId,
  });
  final String previousTenantId;
  final String newTenantId;
  final String? userId;
}

/// Tenant-specific feature not available.
final class TenantFeatureNotAvailableException extends TenantException {
  const TenantFeatureNotAvailableException({
    required super.message,
    required this.tenantId,
    required this.featureKey,
  });
  final String tenantId;
  final String featureKey;
}
