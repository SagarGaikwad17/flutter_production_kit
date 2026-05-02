import 'package:flutter_production_kit/permissions/domain/entities/access_context.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';
import 'package:flutter_production_kit/permissions/engine/policy_evaluator.dart';

/// Deny-overrides authorization policy.
///
/// Security-first strategy:
/// - If ANY role denies access, the request is denied regardless of other roles.
/// - This is the SAFEST policy and should be the default.
/// - Example: User has "doctor" (allows edit) and "viewer" (denies edit).
///   Result: DENIED — the viewer role's deny takes priority.
///
/// Use this policy for:
/// - Patient records
/// - Financial data
/// - Admin actions
/// - Any sensitive resource
class DenyOverridesPolicy extends AuthorizationPolicy {
  const DenyOverridesPolicy();

  @override
  String get name => 'deny_overrides';

  @override
  AuthorizationResult evaluate({
    required AccessContext context,
    required Set<Permission> userPermissions,
    required List<String> userRoles,
    required List<String> denyingRoles,
    required List<String> allowingRoles,
  }) {
    // If there are explicit denying roles, deny takes priority.
    if (denyingRoles.isNotEmpty) {
      return AuthorizationDeniedRoleConflict(
        reason: 'Access denied: deny-overrides policy — '
            '${denyingRoles.length} role(s) explicitly deny this action.',
        denyingRoles: denyingRoles,
        allowingRoles: allowingRoles,
      );
    }

    // Check if user has the required permission.
    final requiredScope = context.resolveScope();
    final hasPermission = userPermissions.any(
      (p) => p.grants(context.action, context.resource, scope: requiredScope),
    );

    if (hasPermission) {
      return AuthorizationAllowed(
        reason: 'Permission granted — no denying roles block this action.',
        viaRole: allowingRoles.isNotEmpty ? allowingRoles.join(', ') : null,
      );
    }

    return AuthorizationDenied(
      reason: 'No role grants "${context.action}" on "${context.resource}".',
      requiredPermission: '${context.action}:${context.resource}:${requiredScope.name}',
      userRoles: userRoles,
    );
  }
}
