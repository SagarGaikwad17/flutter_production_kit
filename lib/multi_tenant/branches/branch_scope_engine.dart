import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_access_result.dart';
import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_context.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Branch scope engine — enforces hierarchical branch access boundaries.
///
/// Design rationale:
/// - Resolves which branches a user can access within a tenant.
/// - Enforces hierarchy rules (managers access child branches).
/// - Supports escalation for super admins.
/// - Returns sealed results for explicit outcome handling.
///
/// Access rules:
/// - Regular users: only assigned branches.
/// - Branch managers: their branch + all child branches.
/// - Super admins: all branches within the tenant.
/// - Cross-tenant: never allowed.
class BranchScopeEngine {
  const BranchScopeEngine({
    required IBranchRepository branchRepository,
    this.escalationRoles = const ['super_admin', 'tenant_admin'],
  }) : _branchRepository = branchRepository;

  final IBranchRepository _branchRepository;
  final List<String> escalationRoles;

  /// Get all branch IDs accessible to a user within a tenant.
  Future<List<String>> getAccessibleBranches({
    required String userId,
    required String tenantId,
    String? role,
  }) async {
    if (role != null && escalationRoles.contains(role)) {
      return _branchRepository.getBranchIdsForTenant(tenantId);
    }
    return _branchRepository.getBranchIdsForUserInTenant(userId, tenantId);
  }

  /// Validate that a user has access to a specific branch.
  Future<TenantAccessResult> validateBranchAccess({
    required TenantContext context,
    required String requestedBranchId,
  }) async {
    if (!context.isValid) {
      return BranchScopeViolation(
        tenantId: context.tenant.id,
        userBranchId: context.branch?.id ?? '',
        requestedBranchId: requestedBranchId,
        userId: context.userId,
      );
    }

    if (!context.tenant.hasBranch(requestedBranchId)) {
      return BranchScopeViolation(
        tenantId: context.tenant.id,
        userBranchId: context.branch?.id ?? '',
        requestedBranchId: requestedBranchId,
        userId: context.userId,
      );
    }

    return TenantResolved(
      tenantId: context.tenant.id,
      tenantSlug: context.tenant.slug,
      correlationId: context.correlationId,
      branchId: requestedBranchId,
    );
  }

  /// Check if a role has escalation privileges.
  bool hasEscalationPrivileges(String? role) {
    return role != null && escalationRoles.contains(role);
  }
}

/// Hierarchy resolver — resolves branch parent-child relationships.
class HierarchyResolver {
  const HierarchyResolver();

  /// Resolve all child branch IDs for a given parent branch.
  List<String> resolveChildBranches({
    required String parentBranchId,
    required Map<String, String> branchParentMap,
  }) {
    final children = <String>[];
    for (final entry in branchParentMap.entries) {
      if (entry.value == parentBranchId) {
        children.add(entry.key);
        children.addAll(
          resolveChildBranches(
            parentBranchId: entry.key,
            branchParentMap: branchParentMap,
          ),
        );
      }
    }
    return children;
  }

  /// Resolve the root branch ID for a given branch.
  String? resolveRootBranch({
    required String branchId,
    required Map<String, String> branchParentMap,
  }) {
    final parent = branchParentMap[branchId];
    if (parent == null) return branchId;
    return resolveRootBranch(
      branchId: parent,
      branchParentMap: branchParentMap,
    );
  }

  /// Get the hierarchy path from root to a specific branch.
  List<String> resolveHierarchyPath({
    required String branchId,
    required Map<String, String> branchParentMap,
  }) {
    final path = <String>[];
    String? current = branchId;
    while (current != null) {
      path.insert(0, current);
      current = branchParentMap[current];
    }
    return path;
  }
}
