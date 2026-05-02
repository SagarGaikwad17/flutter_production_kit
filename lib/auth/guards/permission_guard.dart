import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';
import 'package:flutter_production_kit/auth/session/session_manager.dart';

/// Permission-aware auth guard — fine-grained access control.
///
/// Design rationale:
/// Role-based checks (admin, moderator, user) are coarse-grained.
/// Permission checks are fine-grained — e.g., "can_delete_post", "can_view_analytics".
///
/// Permissions are loaded from the backend during session validation
/// and stored in [AuthSession.permissions].
///
/// This guard combines role AND permission checks for defense in depth:
/// - A user must have the required role AND the specific permission.
/// - Either check alone is not sufficient.
class PermissionGuard {
  PermissionGuard({required SessionManager sessionManager})
      : _sessionManager = sessionManager;

  final SessionManager _sessionManager;

  /// Check if the current user can perform an action.
  ///
  /// Requires BOTH:
  /// 1. The user has at least the minimum role.
  /// 2. The user has the specific permission (if required).
  bool canPerform({
    UserRole? minimumRole,
    String? permission,
  }) {
    if (!_sessionManager.isAuthenticated) return false;

    if (minimumRole != null && !_sessionManager.hasRole(minimumRole)) {
      return false;
    }

    if (permission != null && !_sessionManager.currentSession!.permissions.contains(permission)) {
      return false;
    }

    return true;
  }

  /// Assert permission — throws if not granted.
  void assertPermission(String permission) {
    if (!_sessionManager.isAuthenticated) {
      throw PermissionDeniedException(
        reason: 'Not authenticated',
        permission: permission,
      );
    }

    final session = _sessionManager.currentSession!;

    if (!session.permissions.contains(permission)) {
      throw PermissionDeniedException(
        reason: 'Missing permission: $permission',
        permission: permission,
        userRoles: session.user.roles,
      );
    }
  }

  /// Assert role — throws if not granted.
  void assertRole(UserRole required) {
    if (!_sessionManager.isAuthenticated) {
      throw PermissionDeniedException(
        reason: 'Not authenticated',
        requiredRole: required,
      );
    }

    if (!_sessionManager.hasRole(required)) {
      final session = _sessionManager.currentSession!;
      throw PermissionDeniedException(
        reason: 'Insufficient role',
        requiredRole: required,
        userRoles: session.user.roles,
      );
    }
  }

  /// Get all permissions the current user has.
  List<String> get currentPermissions {
    final session = _sessionManager.currentSession;
    return session?.permissions ?? [];
  }

  /// Check if the user has any of the given permissions.
  bool hasAnyPermission(List<String> permissions) {
    final session = _sessionManager.currentSession;
    if (session == null) return false;
    return permissions.any((p) => session.permissions.contains(p));
  }
}

class PermissionDeniedException implements Exception {
  PermissionDeniedException({
    required this.reason,
    this.permission,
    this.requiredRole,
    this.userRoles,
  });

  final String reason;
  final String? permission;
  final UserRole? requiredRole;
  final List<UserRole>? userRoles;

  @override
  String toString() {
    final parts = [reason];
    if (permission != null) parts.add('permission: $permission');
    if (requiredRole != null) parts.add('requiredRole: $requiredRole');
    if (userRoles != null) parts.add('userRoles: ${userRoles!.map((e) => e.name)}');
    return 'PermissionDeniedException: ${parts.join(', ')}';
  }
}
