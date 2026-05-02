import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';

/// Repository interface for tenant data access.
///
/// Design rationale:
/// - Abstract interface — concrete implementation depends on storage backend.
/// - All queries are tenant-scoped by design.
/// - No cross-tenant queries possible at this layer.
abstract class ITenantRepository {
  Future<TenantEntity?> getById(String tenantId);
  Future<TenantEntity?> getBySlug(String slug);
  Future<List<TenantEntity>> getByUserId(String userId);
  Future<void> save(TenantEntity tenant);
  Future<void> updateStatus(String tenantId, TenantStatus status);
  Future<void> delete(String tenantId);
}

/// Repository interface for branch data access.
abstract class IBranchRepository {
  Future<List<String>> getBranchIdsForTenant(String tenantId);
  Future<List<String>> getBranchIdsForUser(String userId);
  Future<List<String>> getBranchIdsForUserInTenant(String userId, String tenantId);
}

/// Repository interface for branding data access.
abstract class IBrandingRepository {
  Future<Map<String, String>?> getBrandingConfig(String tenantId);
  Future<void> saveBrandingConfig(String tenantId, Map<String, String> config);
  Future<void> clearBrandingConfig(String tenantId);
}

/// Repository interface for tenant session management.
abstract class ITenantSessionRepository {
  Future<String?> getCurrentTenantId();
  Future<void> setCurrentTenantId(String tenantId);
  Future<void> clearCurrentTenantId();
}

/// Repository interface for compliance policy data access.
abstract class ICompliancePolicyRepository {
  Future<Map<String, String>> getPolicies(String tenantId);
  Future<void> savePolicy(String tenantId, String key, String value);
  Future<void> deletePolicy(String tenantId, String key);
}
