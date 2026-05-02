import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';
import 'package:flutter_production_kit/offline/policies/offline_action_policy.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';

/// Offline action guard — validates actions before they're enqueued offline.
///
/// Design rationale:
/// - This is the FIRST line of defense — checks BEFORE an operation enters the queue.
/// - Two checks are performed:
///   1. Policy check: is this action allowed offline? (per [OfflineActionPolicy])
///   2. Permission check: does the user have the required permission? (per [PermissionEngine])
/// - If either check fails, the action is rejected with a clear reason.
/// - Rejected actions are logged for security auditing.
/// - The guard does NOT queue the operation — that's the caller's responsibility.
///
/// Security model:
/// - Offline permissions are checked at ENQUEUE time, not sync time.
/// - Sync-time revalidation (in SyncEngine) is the SECOND line of defense.
/// - This catches permission issues early and gives immediate user feedback.
class OfflineActionGuard {
  OfflineActionGuard({
    required OfflineActionPolicy actionPolicy,
    required PermissionEngine permissionEngine,
    this.enforcePermissionsOffline = true,
  })  : _actionPolicy = actionPolicy,
        _permissionEngine = permissionEngine;

  static const String _tag = 'OfflineActionGuard';

  final OfflineActionPolicy _actionPolicy;
  final PermissionEngine _permissionEngine;
  final bool enforcePermissionsOffline;

  /// Validate an action before enqueueing it offline.
  ///
  /// Returns [OfflineActionValidation] with the result and reason.
  OfflineActionValidation validate({
    required String resourceType,
    required SyncAction action,
    required String userId,
    String? resourceId,
    String? branchId,
    String? tenantId,
  }) {
    // Check 1: Offline policy — is this action allowed offline?
    final safety = _actionPolicy.check(resourceType: resourceType, action: action);

    if (safety == OfflineActionSafety.blocked) {
      AppLogger.warning(
        _tag,
        'Action blocked offline: $action $resourceType '
        '(policy: ${_actionPolicy.globalDefault.name})',
      );

      return OfflineActionValidation(
        allowed: false,
        reason: 'Action "${action.name}" on "$resourceType" is not allowed offline.',
        safety: safety,
      );
    }

    // Check 2: Permission check (if enabled).
    if (enforcePermissionsOffline) {
      final permissionResult = _permissionEngine.check(
        userId: userId,
        action: _mapActionToPermission(action),
        resource: resourceType,
        resourceId: resourceId,
        branchId: branchId,
        tenantId: tenantId,
        isOnline: false,
      );

      if (!permissionResult.isAllowed) {
        AppLogger.warning(
          _tag,
          'Permission denied for offline action: $action $resourceType '
          '(${permissionResult.runtimeType})',
        );

        return OfflineActionValidation(
          allowed: false,
          reason: 'Permission denied: ${permissionResult.runtimeType}',
          safety: safety,
          permissionResult: permissionResult,
        );
      }
    }

    // Check 3: Warning-level actions.
    if (safety == OfflineActionSafety.allowedWithWarning) {
      return OfflineActionValidation(
        allowed: true,
        reason: 'Action allowed with warning — will sync when online.',
        safety: safety,
        requiresUserConfirmation: true,
      );
    }

    return OfflineActionValidation(
      allowed: true,
      reason: 'Action allowed offline.',
      safety: safety,
    );
  }

  String _mapActionToPermission(SyncAction action) {
    return switch (action) {
      SyncAction.create => 'create',
      SyncAction.update => 'update',
      SyncAction.delete => 'delete',
      SyncAction.replace => 'update',
    };
  }
}

/// Result of an offline action validation.
class OfflineActionValidation {
  const OfflineActionValidation({
    required this.allowed,
    required this.reason,
    required this.safety,
    this.permissionResult,
    this.requiresUserConfirmation = false,
  });

  final bool allowed;
  final String reason;
  final OfflineActionSafety safety;
  final dynamic permissionResult;
  final bool requiresUserConfirmation;
}
