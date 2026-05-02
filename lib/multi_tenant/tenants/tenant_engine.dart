import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';
import 'package:flutter_production_kit/multi_tenant/domain/exceptions/tenant_exception.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Tenant engine — core tenant lifecycle operations.
///
/// Design rationale:
/// - Orchestrates tenant CRUD with isolation guarantees.
/// - Validates tenant state before operations.
/// - Delegates to ITenantRepository for persistence.
class TenantEngine {
  const TenantEngine({required ITenantRepository tenantRepository})
      : _tenantRepository = tenantRepository;

  final ITenantRepository _tenantRepository;

  /// Resolve tenant by ID with validation.
  Future<TenantEntity> resolveTenant(String tenantId) async {
    final tenant = await _tenantRepository.getById(tenantId);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found',
      );
    }
    if (tenant.isSuspended) {
      throw const TenantNotFoundException(
        message: 'Tenant is suspended',
      );
    }
    if (tenant.isExpired) {
      throw const TenantNotFoundException(
        message: 'Tenant has expired',
      );
    }
    return tenant;
  }

  /// Resolve tenant by slug.
  Future<TenantEntity> resolveTenantBySlug(String slug) async {
    final tenant = await _tenantRepository.getBySlug(slug);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found by slug',
      );
    }
    return tenant;
  }

  /// Get all tenants for a user.
  Future<List<TenantEntity>> getUserTenants(String userId) async {
    return _tenantRepository.getByUserId(userId);
  }

  /// Activate a pending tenant.
  Future<void> activateTenant(String tenantId) async {
    final tenant = await _tenantRepository.getById(tenantId);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Cannot activate — tenant not found',
      );
    }
    if (tenant.status != TenantStatus.pending) {
      throw TenantNotFoundException(
        message: 'Cannot activate — tenant status is ${tenant.status}',
      );
    }
    await _tenantRepository.updateStatus(tenantId, TenantStatus.active);
  }

  /// Suspend a tenant.
  Future<void> suspendTenant(String tenantId, {String? reason}) async {
    await _tenantRepository.updateStatus(tenantId, TenantStatus.suspended);
  }

  /// Archive a tenant.
  Future<void> archiveTenant(String tenantId) async {
    await _tenantRepository.updateStatus(tenantId, TenantStatus.archived);
  }
}
