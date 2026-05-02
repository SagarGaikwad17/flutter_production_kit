import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';

/// Context for an authorization check — who is accessing what, where, and why.
///
/// Design rationale:
/// - All authorization decisions are evaluated against a complete context.
/// - [userId] and [branchId] enable ownership and branch isolation checks.
/// - [tenantId] enables multi-tenant isolation.
/// - [resourceId] enables ownership-aware permission checks.
/// - [resourceOwnerId] enables "own" scope evaluation.
/// - [action] is the operation being attempted.
/// - [resource] is the target entity type.
/// - [isOnline] affects offline permission policy.
class AccessContext {
  const AccessContext({
    required this.userId,
    required this.action,
    required this.resource,
    this.resourceId,
    this.resourceOwnerId,
    this.branchId,
    this.tenantId,
    this.metadata = const {},
    this.isOnline = true,
  });

  final String userId;
  final String action;
  final String resource;
  final String? resourceId;
  final String? resourceOwnerId;
  final String? branchId;
  final String? tenantId;
  final Map<String, String> metadata;
  final bool isOnline;

  /// Whether this is an ownership check (accessing own resource).
  bool get isOwnershipCheck =>
      resourceOwnerId != null && resourceOwnerId == userId;

  /// Resolve the effective scope based on context.
  PermissionScope resolveScope() {
    if (isOwnershipCheck) return PermissionScope.own;
    if (branchId != null) return PermissionScope.branch;
    return PermissionScope.global;
  }

  AccessContext copyWith({
    String? userId,
    String? action,
    String? resource,
    String? resourceId,
    String? resourceOwnerId,
    String? branchId,
    String? tenantId,
    Map<String, String>? metadata,
    bool? isOnline,
  }) {
    return AccessContext(
      userId: userId ?? this.userId,
      action: action ?? this.action,
      resource: resource ?? this.resource,
      resourceId: resourceId ?? this.resourceId,
      resourceOwnerId: resourceOwnerId ?? this.resourceOwnerId,
      branchId: branchId ?? this.branchId,
      tenantId: tenantId ?? this.tenantId,
      metadata: metadata ?? this.metadata,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() =>
      'AccessContext(user: $userId, $action:$resource, branch: $branchId)';
}
