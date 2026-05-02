import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';
import 'package:flutter_production_kit/permissions/domain/entities/role.dart';
import 'package:flutter_production_kit/permissions/domain/entities/temporary_permission.dart';
import 'package:flutter_production_kit/permissions/policies/temporary_access_policy.dart';

/// Resolves effective permissions from multiple roles.
///
/// Design rationale:
/// - Users can have multiple roles (e.g., "doctor" + "branch_manager").
/// - Permissions from all roles are merged.
/// - Temporary permissions (time-bound elevation) are layered on top.
/// - Role inheritance is resolved (senior_doctor inherits from doctor).
/// - Conflict resolution is delegated to the policy evaluator.
class RoleResolver {
  RoleResolver({
    TemporaryAccessPolicy? temporaryAccessPolicy,
  }) : _temporaryPolicy = temporaryAccessPolicy ?? const TemporaryAccessPolicy();

  static const String _tag = 'RoleResolver';

  final TemporaryAccessPolicy _temporaryPolicy;

  List<TemporaryPermission> _activeTemporaryPermissions = [];

  /// Resolve effective permissions from the user's roles.
  ///
  /// Merges permissions from all roles the user has, resolving inheritance.
  Set<Permission> resolveEffectivePermissions({
    required List<Role> allRoles,
    required List<String> userRoleIds,
  }) {
    final userRoles = allRoles.where((r) => userRoleIds.contains(r.id)).toList();

    // Resolve inheritance first.
    final resolvedRoles = _resolveInheritance(userRoles, allRoles);

    // Merge all permissions.
    final permissions = <Permission>{};
    for (final role in resolvedRoles) {
      permissions.addAll(role.permissions);
    }

    // Layer on temporary permissions.
    final tempPermissions = _getActiveTemporaryPermissions();
    for (final temp in tempPermissions) {
      permissions.addAll(temp.permissions);
    }

    AppLogger.debug(
      _tag,
      'Resolved ${permissions.length} effective permissions '
      'from ${resolvedRoles.length} roles + ${tempPermissions.length} temp permissions.',
    );

    return permissions;
  }

  /// Resolve role inheritance — build the full permission tree.
  List<Role> _resolveInheritance(List<Role> userRoles, List<Role> allRoles) {
    final resolved = <Role>[];

    for (final role in userRoles) {
      if (role.inheritedFrom != null) {
        final parent = allRoles.where((r) => r.id == role.inheritedFrom).firstOrNull;
        if (parent != null) {
          resolved.add(role.inheritFrom(parent));
        } else {
          resolved.add(role);
        }
      } else {
        resolved.add(role);
      }
    }

    return resolved;
  }

  /// Set the active temporary permissions for the current user.
  void setTemporaryPermissions(List<TemporaryPermission> permissions) {
    _activeTemporaryPermissions = permissions
        .where((p) => _temporaryPolicy.isValid(p))
        .toList();

    AppLogger.info(
      _tag,
      'Temporary permissions updated: ${_activeTemporaryPermissions.length} active.',
    );
  }

  List<TemporaryPermission> _getActiveTemporaryPermissions() {
    // Filter out expired permissions.
    _activeTemporaryPermissions = _activeTemporaryPermissions
        .where((p) => p.isActive)
        .toList();

    return _activeTemporaryPermissions;
  }

  /// Get temporary permissions that are about to expire (within 15 minutes).
  List<TemporaryPermission> get expiringSoon {
    final now = DateTime.now();
    final threshold = now.add(const Duration(minutes: 15));
    return _activeTemporaryPermissions
        .where((p) => p.expiresAt.isBefore(threshold) && p.isActive)
        .toList();
  }

  /// Force-expire a temporary permission (admin revocation).
  void revokeTemporaryPermission(String id) {
    final before = _activeTemporaryPermissions.length;
    _activeTemporaryPermissions = _activeTemporaryPermissions
        .where((p) => p.id != id)
        .toList();

    if (_activeTemporaryPermissions.length < before) {
      AppLogger.warning(_tag, 'Temporary permission revoked: $id');
    }
  }
}
