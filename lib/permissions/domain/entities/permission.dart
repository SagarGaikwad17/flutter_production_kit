/// Represents a single permission — the atomic unit of authorization.
///
/// Design rationale:
/// - [action] is the operation (read, write, delete, admin, export, etc.).
/// - [resource] is the target entity type (user, patient, billing, report, etc.).
/// - [scope] limits the permission context (own, branch, tenant, global).
/// - The combination (action + resource + scope) forms a unique permission key.
/// - This is NOT role-based — roles are collections of permissions.
/// - The string representation is stable across app versions.
class Permission {
  const Permission({
    required this.action,
    required this.resource,
    this.scope = PermissionScope.global,
    this.branchId,
    this.conditions = const {},
  });

  final String action;
  final String resource;
  final PermissionScope scope;
  final String? branchId;
  final Map<String, String> conditions;

  /// Unique permission key: "action:resource:scope".
  String get key => '$action:$resource:${scope.name}';

  /// Permission with all fields.
  String get fullKey {
    final parts = [action, resource, scope.name];
    if (branchId != null) parts.add('branch:$branchId');
    return parts.join(':');
  }

  /// Check if this permission grants the specified action on the resource.
  bool grants(String action, String resource, {PermissionScope? scope}) {
    if (this.action != action) return false;
    if (this.resource != resource) return false;
    if (scope != null && this.scope.level > scope.level) return false;
    return true;
  }

  @override
  String toString() => 'Permission($key${branchId != null ? ' branch:$branchId' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          branchId == other.branchId;

  @override
  int get hashCode => Object.hash(key, branchId);
}

/// Permission scope — limits where a permission applies.
///
/// Higher levels encompass lower levels (global includes branch includes own).
enum PermissionScope {
  /// Permission applies only to resources owned by the user.
  own(level: 10),

  /// Permission applies to resources within the user's branch.
  branch(level: 50),

  /// Permission applies to all resources within the tenant.
  tenant(level: 100),

  /// Permission applies globally — no restrictions.
  global(level: 999);

  const PermissionScope({required this.level});

  final int level;

  bool canAccess(PermissionScope required) => level >= required.level;
}
