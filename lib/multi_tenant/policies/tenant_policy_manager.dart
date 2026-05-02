import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Tenant policy manager — manages tenant-specific compliance and security policies.
///
/// Design rationale:
/// - Policies are stored per-tenant.
/// - Supports policy evaluation with context.
/// - Supports policy inheritance from tier defaults.
/// - Supports policy override for enterprise tenants.
///
/// Policy types:
/// - Session timeout policies.
/// - Password complexity policies.
/// - Data retention policies.
/// - Audit logging policies.
/// - IP whitelist/blacklist policies.
/// - MFA enforcement policies.
class TenantPolicyManager {
  const TenantPolicyManager({
    required ICompliancePolicyRepository policyRepository,
    Map<TenantTier, Map<String, String>>? tierDefaultPolicies,
  })  : _policyRepository = policyRepository,
        _tierDefaultPolicies = tierDefaultPolicies ?? _defaultTierPolicies;

  final ICompliancePolicyRepository _policyRepository;
  final Map<TenantTier, Map<String, String>> _tierDefaultPolicies;

  static const Map<TenantTier, Map<String, String>> _defaultTierPolicies = {
    TenantTier.free: {
      'session_timeout': '30',
      'max_sessions': '1',
      'audit_retention_days': '30',
    },
    TenantTier.standard: {
      'session_timeout': '60',
      'max_sessions': '3',
      'audit_retention_days': '90',
      'mfa_required': 'false',
    },
    TenantTier.professional: {
      'session_timeout': '120',
      'max_sessions': '10',
      'audit_retention_days': '365',
      'mfa_required': 'true',
      'ip_whitelist_enabled': 'false',
    },
    TenantTier.enterprise: {
      'session_timeout': '480',
      'max_sessions': 'unlimited',
      'audit_retention_days': '3650',
      'mfa_required': 'true',
      'ip_whitelist_enabled': 'true',
      'sso_required': 'true',
      'data_residency': 'configurable',
    },
  };

  /// Get a policy value for a tenant.
  Future<String?> getPolicy({
    required String tenantId,
    required String policyKey,
    TenantTier? tier,
  }) async {
    final policies = await _policyRepository.getPolicies(tenantId);
    final value = policies[policyKey];
    if (value != null) return value;

    if (tier != null) {
      return _tierDefaultPolicies[tier]?[policyKey];
    }
    return null;
  }

  /// Evaluate if a policy condition is met.
  Future<bool> evaluatePolicy({
    required String tenantId,
    required String policyKey,
    required String expectedValue,
    TenantTier? tier,
  }) async {
    final value = await getPolicy(
      tenantId: tenantId,
      policyKey: policyKey,
      tier: tier,
    );
    return value == expectedValue;
  }

  /// Get all policies for a tenant.
  Future<Map<String, String>> getAllPolicies(String tenantId) async {
    return _policyRepository.getPolicies(tenantId);
  }

  /// Save a policy for a tenant.
  Future<void> savePolicy({
    required String tenantId,
    required String key,
    required String value,
  }) async {
    await _policyRepository.savePolicy(tenantId, key, value);
  }

  /// Delete a policy for a tenant.
  Future<void> deletePolicy({
    required String tenantId,
    required String key,
  }) async {
    await _policyRepository.deletePolicy(tenantId, key);
  }
}
