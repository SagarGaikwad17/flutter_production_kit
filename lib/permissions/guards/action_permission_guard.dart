import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';

/// Action-level permission guard — protects individual UI actions.
///
/// Design rationale:
/// - Lightweight check for button taps, menu items, and UI actions.
/// - Returns the full [AuthorizationResult] so the UI can show specific
///   denial messages (e.g., "Upgrade to premium" vs "Contact admin").
/// - NOT a replacement for service-level guards — UI checks are UX, not security.
///   Service guards (see [ServicePermissionGuard]) are the real security layer.
///
/// Usage:
/// ```dart
/// final result = guard.check(action: 'delete', resource: 'patient');
/// if (result.isAllowed) {
///   _performDelete();
/// } else {
///   _showDenialMessage(result);
/// }
/// ```
class ActionPermissionGuard {
  ActionPermissionGuard({
    required PermissionEngine permissionEngine,
    required String userId,
    String? branchId,
    String? tenantId,
  })  : _engine = permissionEngine,
        _userId = userId,
        _branchId = branchId,
        _tenantId = tenantId;

  final PermissionEngine _engine;
  final String _userId;
  final String? _branchId;
  final String? _tenantId;

  /// Check permission for an action.
  AuthorizationResult check({
    required String action,
    required String resource,
    String? resourceId,
    String? resourceOwnerId,
    List<String>? requiredEntitlements,
    bool isOnline = true,
  }) {
    return _engine.check(
      userId: _userId,
      action: action,
      resource: resource,
      resourceId: resourceId,
      resourceOwnerId: resourceOwnerId,
      branchId: _branchId,
      tenantId: _tenantId,
      requiredEntitlements: requiredEntitlements,
      isOnline: isOnline,
    );
  }

  /// Quick boolean check.
  bool can({
    required String action,
    required String resource,
    String? resourceId,
    String? resourceOwnerId,
    bool isOnline = true,
  }) {
    return _engine.can(
      userId: _userId,
      action: action,
      resource: resource,
      resourceId: resourceId,
      resourceOwnerId: resourceOwnerId,
      branchId: _branchId,
      tenantId: _tenantId,
      isOnline: isOnline,
    );
  }
}
