import 'package:flutter_production_kit/permissions/domain/entities/access_context.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';
import 'package:flutter_production_kit/permissions/engine/policy_evaluator.dart';

/// Allow-overrides authorization policy.
///
/// Permissive strategy:
/// - If ANY role grants access, the request is allowed even if other roles deny it.
/// - This is LESS secure and should only be used for low-risk resources.
/// - Example: User has "viewer" (denies export) and "analyst" (allows export).
///   Result: ALLOWED — the analyst role's allow takes priority.
///
/// Use this policy ONLY for:
/// - Read-only public data
/// - Non-sensitive reports
/// - Resources where partial access is acceptable
///
/// NEVER use for:
/// - Patient records
/// - Financial data
/// - Admin/destructive actions
class AllowOverridesPolicy extends AuthorizationPolicy {
  const AllowOverridesPolicy();

  @override
  String get name => 'allow_overrides';

  @override
  AuthorizationResult evaluate({
    required AccessContext context,
    required Set<Permission> userPermissions,
    required List<String> userRoles,
    required List<String> denyingRoles,
    required List<String> allowingRoles,
  }) {
    // Check if user has the required permission — allow takes priority.
    final requiredScope = context.resolveScope();
    final hasPermission = userPermissions.any(
      (p) => p.grants(context.action, context.resource, scope: requiredScope),
    );

    if (hasPermission) {
      return AuthorizationAllowed(
        reason: 'Permission granted — allow-overrides policy permits this action.',
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
