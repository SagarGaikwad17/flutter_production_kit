/// Sealed authorization result hierarchy.
///
/// Design rationale:
/// Every authorization check returns a typed result — never a simple bool.
/// This forces call sites to handle each denial reason explicitly.
/// The result carries enough context for the UI to show the correct message
/// and for the engine to log the appropriate security event.
sealed class AuthorizationResult {
  const AuthorizationResult();

  bool get isAllowed => this is AuthorizationAllowed;
  bool get isDenied => this is! AuthorizationAllowed;
}

/// Access granted — user has the required permission.
final class AuthorizationAllowed extends AuthorizationResult {
  const AuthorizationAllowed({
    this.reason,
    this.viaRole,
    this.viaTemporaryPermission,
    this.viaEntitlement,
  });

  final String? reason;
  final String? viaRole;
  final String? viaTemporaryPermission;
  final String? viaEntitlement;
}

/// Access denied — generic denial.
final class AuthorizationDenied extends AuthorizationResult {
  const AuthorizationDenied({
    required this.reason,
    this.requiredPermission,
    this.userRoles,
  });

  final String reason;
  final String? requiredPermission;
  final List<String>? userRoles;
}

/// Access denied — temporary permission has expired.
final class AuthorizationDeniedExpired extends AuthorizationResult {
  const AuthorizationDeniedExpired({
    required this.reason,
    this.expiredAt,
    this.temporaryPermissionId,
  });

  final String reason;
  final DateTime? expiredAt;
  final String? temporaryPermissionId;
}

/// Access denied — feature entitlement missing.
final class AuthorizationDeniedEntitlementMissing extends AuthorizationResult {
  const AuthorizationDeniedEntitlementMissing({
    required this.reason,
    required this.requiredFeature,
    this.requiredTier,
    this.currentTier,
  });

  final String reason;
  final String requiredFeature;
  final String? requiredTier;
  final String? currentTier;
}

/// Access denied — branch isolation violation.
final class AuthorizationDeniedBranchMismatch extends AuthorizationResult {
  const AuthorizationDeniedBranchMismatch({
    required this.reason,
    this.userBranchId,
    this.resourceBranchId,
  });

  final String reason;
  final String? userBranchId;
  final String? resourceBranchId;
}

/// Access denied — stale local permission, backend sync required.
final class AuthorizationDeniedStalePermission extends AuthorizationResult {
  const AuthorizationDeniedStalePermission({
    required this.reason,
    this.lastSyncedAt,
    this.staleDuration,
  });

  final String reason;
  final DateTime? lastSyncedAt;
  final Duration? staleDuration;
}

/// Access denied — offline mode blocks this action.
final class AuthorizationDeniedOffline extends AuthorizationResult {
  const AuthorizationDeniedOffline({
    required this.reason,
    this.allowedWhenOffline = false,
  });

  final String reason;
  final bool allowedWhenOffline;
}

/// Access denied — ownership check failed.
final class AuthorizationDeniedOwnership extends AuthorizationResult {
  const AuthorizationDeniedOwnership({
    required this.reason,
    this.userId,
    this.resourceOwnerId,
  });

  final String reason;
  final String? userId;
  final String? resourceOwnerId;
}

/// Access denied — tenant isolation violation.
final class AuthorizationDeniedTenantMismatch extends AuthorizationResult {
  const AuthorizationDeniedTenantMismatch({
    required this.reason,
    this.userTenantId,
    this.resourceTenantId,
  });

  final String reason;
  final String? userTenantId;
  final String? resourceTenantId;
}

/// Access denied — role conflict (deny-overrides policy).
final class AuthorizationDeniedRoleConflict extends AuthorizationResult {
  const AuthorizationDeniedRoleConflict({
    required this.reason,
    this.denyingRoles = const [],
    this.allowingRoles = const [],
  });

  final String reason;
  final List<String> denyingRoles;
  final List<String> allowingRoles;
}
