import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';
import 'package:flutter_production_kit/permissions/domain/entities/role.dart';

/// Time-bound elevated access — permissions that expire automatically.
///
/// Design rationale:
/// - [grantedAt] and [expiresAt] define the validity window.
/// - [grantedBy] tracks who authorized the elevation (audit trail).
/// - [reason] documents why elevated access was granted.
/// - [permissions] are the additional permissions granted during this window.
/// - After expiry, permissions are automatically revoked — no manual cleanup needed.
class TemporaryPermission {
  const TemporaryPermission({
    required this.id,
    required this.userId,
    required this.permissions,
    required this.grantedAt,
    required this.expiresAt,
    required this.grantedBy,
    this.reason,
    this.roles = const [],
    this.scope = TemporaryAccessScope.all,
  });

  final String id;
  final String userId;
  final Set<Permission> permissions;
  final DateTime grantedAt;
  final DateTime expiresAt;
  final String grantedBy;
  final String? reason;
  final List<Role> roles;
  final TemporaryAccessScope scope;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  @override
  String toString() =>
      'TemporaryPermission($id, user: $userId, expires: $expiresAt, active: $isActive)';
}

/// Scope of temporary access — what the elevated permissions apply to.
enum TemporaryAccessScope {
  /// Access limited to specific resource.
  resource,

  /// Access limited to specific branch.
  branch,

  /// Access applies to all resources (full elevation).
  all,
}
