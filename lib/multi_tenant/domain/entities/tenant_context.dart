import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';
import 'package:flutter_production_kit/multi_tenant/domain/entities/branch_entity.dart';

/// Tenant context — the resolved operational context for the current session.
///
/// Design rationale:
/// - [tenant] is the resolved tenant entity.
/// - [branch] is the current branch scope (if applicable).
/// - [userId] is the authenticated user.
/// - [resolvedAt] enables staleness detection.
/// - [correlationId] links to observability traces.
/// - [isValid] determines if the context is still valid.
///
/// Context invalidation rules:
/// - Tenant switch → context invalidates immediately.
/// - Session expiry → context invalidates.
/// - Branch change → context invalidates for branch-scoped operations.
/// - Subscription status change → context may invalidate.
class TenantContext {
  const TenantContext({
    required this.tenant,
    required this.userId,
    required this.resolvedAt,
    required this.correlationId,
    this.branch,
    this.validUntil,
    this.role,
    this.permissions = const [],
  });

  final TenantEntity tenant;
  final BranchEntity? branch;
  final String userId;
  final DateTime resolvedAt;
  final String correlationId;
  final DateTime? validUntil;
  final String? role;
  final List<String> permissions;

  bool get isValid {
    final until = validUntil;
    if (until != null && DateTime.now().isAfter(until)) return false;
    if (!tenant.isActive) return false;
    return true;
  }

  bool get hasBranchScope => branch != null;

  TenantContext withBranch(BranchEntity newBranch) {
    return TenantContext(
      tenant: tenant,
      branch: newBranch,
      userId: userId,
      resolvedAt: resolvedAt,
      correlationId: correlationId,
      validUntil: validUntil,
      role: role,
      permissions: permissions,
    );
  }

  TenantContext invalidate() {
    return TenantContext(
      tenant: tenant,
      userId: userId,
      resolvedAt: resolvedAt,
      correlationId: correlationId,
      branch: branch,
      validUntil: DateTime.now(),
      role: role,
      permissions: permissions,
    );
  }

  static TenantContext get empty => TenantContext(
    tenant: TenantEntity(
      id: '',
      slug: '',
      name: '',
      tier: TenantTier.free,
      status: TenantStatus.pending,
      environment: TenantEnvironment.production,
    ),
    userId: '',
    resolvedAt: DateTime.utc(1970),
    correlationId: '',
  );
}
