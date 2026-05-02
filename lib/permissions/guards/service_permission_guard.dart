import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Service-level permission guard — protects API calls and business operations.
///
/// Design rationale:
/// - Route guards protect navigation. Service guards protect operations.
/// - Called BEFORE any API request or business logic execution.
/// - If the check fails, throws [PermissionGuardException] — the caller
///   MUST handle it, preventing silent permission bypass.
/// - Supports resource ownership checks for fine-grained access control.
///
/// Usage in a service:
/// ```dart
/// class PatientService {
///   final ServicePermissionGuard _guard;
///
///   Future<void> deletePatient(String patientId) async {
///     await _guard.require(
///       action: 'delete',
///       resource: 'patient',
///       resourceId: patientId,
///     );
///     // ... proceed with deletion
///   }
/// }
/// ```
class ServicePermissionGuard {
  ServicePermissionGuard({
    required PermissionEngine permissionEngine,
    required String userId,
    String? branchId,
    String? tenantId,
  })  : _engine = permissionEngine,
        _userId = userId,
        _branchId = branchId,
        _tenantId = tenantId;

  static const String _tag = 'ServicePermissionGuard';

  final PermissionEngine _engine;
  final String _userId;
  final String? _branchId;
  final String? _tenantId;

  /// Require permission — throws if not granted.
  Future<void> require({
    required String action,
    required String resource,
    String? resourceId,
    String? resourceOwnerId,
    List<String>? requiredEntitlements,
  }) async {
    final result = _engine.check(
      userId: _userId,
      action: action,
      resource: resource,
      resourceId: resourceId,
      resourceOwnerId: resourceOwnerId,
      branchId: _branchId,
      tenantId: _tenantId,
      requiredEntitlements: requiredEntitlements,
      isOnline: true,
    );

    if (!result.isAllowed) {
      AppLogger.warning(
        _tag,
        'Service permission denied: $action:$resource for user $_userId '
        '(${result.runtimeType})',
      );
      throw PermissionGuardException(
        reason: _describeReason(result),
        result: result,
        action: action,
        resource: resource,
      );
    }
  }

  /// Require permission — returns bool instead of throwing.
  ///
  /// Use this when you want to handle denial gracefully without exceptions.
  Future<bool> can({
    required String action,
    required String resource,
    String? resourceId,
    String? resourceOwnerId,
    List<String>? requiredEntitlements,
  }) async {
    return _engine.check(
      userId: _userId,
      action: action,
      resource: resource,
      resourceId: resourceId,
      resourceOwnerId: resourceOwnerId,
      branchId: _branchId,
      tenantId: _tenantId,
      requiredEntitlements: requiredEntitlements,
      isOnline: true,
    ).isAllowed;
  }

  /// Update the guard's context (branch, tenant) — call when user switches context.
  void updateContext({String? branchId, String? tenantId}) {
    // In a real implementation, you'd recreate the guard or update internal state.
  }

  String _describeReason(AuthorizationResult result) {
    return switch (result) {
      AuthorizationDenied(:final reason) => reason,
      AuthorizationDeniedExpired(:final reason) => reason,
      AuthorizationDeniedEntitlementMissing(:final reason) => reason,
      AuthorizationDeniedBranchMismatch(:final reason) => reason,
      AuthorizationDeniedStalePermission(:final reason) => reason,
      AuthorizationDeniedOffline(:final reason) => reason,
      AuthorizationDeniedOwnership(:final reason) => reason,
      AuthorizationDeniedTenantMismatch(:final reason) => reason,
      AuthorizationDeniedRoleConflict(:final reason) => reason,
      AuthorizationAllowed() => 'allowed',
    };
  }
}

class PermissionGuardException implements Exception {
  PermissionGuardException({
    required this.reason,
    required this.result,
    required this.action,
    required this.resource,
  });

  final String reason;
  final AuthorizationResult result;
  final String action;
  final String resource;

  @override
  String toString() => 'PermissionGuardException($action:$resource): $reason';
}
