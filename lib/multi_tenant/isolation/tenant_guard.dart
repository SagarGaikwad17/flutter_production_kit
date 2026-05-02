import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_context.dart';
import 'package:flutter_production_kit/multi_tenant/domain/exceptions/tenant_exception.dart';

/// Tenant guard — enforces tenant isolation at the application layer.
///
/// Design rationale:
/// - Validates tenant context before critical operations.
/// - Prevents cross-tenant data access.
/// - Throws specific exceptions for isolation violations.
/// - Called by API interceptors, cache layers, and business logic.
class TenantGuard {
  const TenantGuard();

  /// Validate that the current context is valid for the requested tenant.
  void validateTenantContext({
    required TenantContext context,
    required String requestedTenantId,
  }) {
    if (!context.isValid) {
      throw const TenantContextExpiredException(
        message: 'Tenant context is invalid or expired',
      );
    }

    if (context.tenant.id != requestedTenantId) {
      throw CrossTenantDataLeakException(
        message: 'Tenant mismatch detected',
        userTenantId: context.tenant.id,
        accessedTenantId: requestedTenantId,
        userId: context.userId,
      );
    }
  }

  /// Validate that a branch access is within the current tenant.
  void validateBranchAccess({
    required TenantContext context,
    required String branchTenantId,
  }) {
    if (context.tenant.id != branchTenantId) {
      throw CrossTenantDataLeakException(
        message: 'Cross-tenant branch access detected',
        userTenantId: context.tenant.id,
        accessedTenantId: branchTenantId,
        userId: context.userId,
        resourceType: 'branch',
      );
    }
  }

  /// Validate that a resource belongs to the current tenant.
  void validateResourceOwnership({
    required TenantContext context,
    required String resourceTenantId,
    required String resourceType,
    String? resourceId,
  }) {
    if (context.tenant.id != resourceTenantId) {
      throw CrossTenantDataLeakException(
        message: 'Cross-tenant resource access detected',
        userTenantId: context.tenant.id,
        accessedTenantId: resourceTenantId,
        userId: context.userId,
        resourceType: resourceType,
        resourceId: resourceId,
      );
    }
  }
}
