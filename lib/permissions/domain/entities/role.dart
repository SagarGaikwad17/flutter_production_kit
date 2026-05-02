import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';

/// Role definition — a named collection of permissions.
///
/// Design rationale:
/// - [id] is the stable identifier synced from the backend.
/// - [permissions] are the effective permissions this role grants.
/// - [inheritedFrom] tracks role inheritance (e.g., "senior_doctor" inherits from "doctor").
/// - [metadata] carries extra context (display name, color, icon) for UI.
class Role {
  const Role({
    required this.id,
    required this.name,
    required this.permissions,
    this.inheritedFrom,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final Set<Permission> permissions;
  final String? inheritedFrom;
  final Map<String, String> metadata;

  /// Check if this role has a specific permission.
  bool hasPermission(String action, String resource, {PermissionScope? scope}) {
    return permissions.any((p) => p.grants(action, resource, scope: scope));
  }

  /// Check if this role has a specific permission key.
  bool hasPermissionKey(String key) {
    return permissions.any((p) => p.key == key);
  }

  /// Merge permissions from a parent role.
  Role inheritFrom(Role parent) {
    return Role(
      id: id,
      name: name,
      permissions: {...permissions, ...parent.permissions},
      inheritedFrom: parent.id,
      metadata: metadata,
    );
  }

  @override
  String toString() => 'Role($name, ${permissions.length} permissions)';
}
