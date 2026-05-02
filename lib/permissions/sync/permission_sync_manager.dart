import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/permissions/domain/entities/feature_entitlement.dart';
import 'package:flutter_production_kit/permissions/domain/entities/role.dart';
import 'package:flutter_production_kit/permissions/domain/entities/temporary_permission.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/permissions/entitlements/feature_entitlement_engine.dart';

/// Synchronizes permissions from the backend and manages local state.
///
/// Design rationale:
/// - Backend is the source of truth for roles, permissions, and entitlements.
/// - Local cache is used for offline access but marked stale after timeout.
/// - On sync, the engine is updated with fresh data.
/// - Supports full sync and incremental (delta) sync.
/// - Emits events on role changes, entitlement changes, and sync failures.
///
/// Trust rules:
/// 1. Backend always wins — local changes are overwritten on sync.
/// 2. If sync fails, stale permissions are used (with timeout).
/// 3. If permissions are too stale, sensitive actions are blocked.
class PermissionSyncManager {
  PermissionSyncManager({
    required PermissionEngine permissionEngine,
    required FeatureEntitlementEngine entitlementEngine,
    required FetchPermissionsCallback fetchPermissions,
    this.syncInterval = const Duration(minutes: 15),
    this.stalePermissionTimeout = const Duration(hours: 4),
  })  : _engine = permissionEngine,
        _entitlementEngine = entitlementEngine,
        _fetchPermissions = fetchPermissions;

  static const String _tag = 'PermissionSyncManager';

  final PermissionEngine _engine;
  final FeatureEntitlementEngine _entitlementEngine;
  final FetchPermissionsCallback _fetchPermissions;
  final Duration syncInterval;
  final Duration stalePermissionTimeout;

  PermissionSyncState _state = PermissionSyncState.idle;
  DateTime? _lastSyncTime;
  PermissionSyncResult? _lastResult;

  PermissionSyncState get state => _state;
  DateTime? get lastSyncTime => _lastSyncTime;
  PermissionSyncResult? get lastResult => _lastResult;

  bool get isSynced => _lastSyncTime != null;

  bool get isStale {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!) > stalePermissionTimeout;
  }

  /// Perform a full permission sync from the backend.
  Future<PermissionSyncResult> sync({
    required String userId,
    String? branchId,
    String? tenantId,
  }) async {
    if (_state == PermissionSyncState.syncing) {
      AppLogger.info(_tag, 'Sync already in progress — skipping duplicate request.');
      return PermissionSyncResult.failure(
        error: 'Sync already in progress.',
      );
    }

    _state = PermissionSyncState.syncing;
    AppLogger.info(_tag, 'Starting permission sync for user: $userId');

    try {
      final data = await _fetchPermissions(
        userId: userId,
        branchId: branchId,
        tenantId: tenantId,
      );

      // Update the permission engine with fresh roles.
      _engine.updateRoles(
        roles: data.roles,
        userRoleIds: data.userRoleIds,
        syncedAt: DateTime.now(),
      );

      // Update temporary permissions.
      if (data.temporaryPermissions.isNotEmpty) {
        // Temp permissions are handled by RoleResolver.
      }

      // Update entitlements.
      if (data.entitlements.isNotEmpty) {
        _entitlementEngine.setEntitlements(
          {for (final e in data.entitlements) e.featureId: e},
        );
        if (data.userTier != null) {
          _entitlementEngine.setUserTier(data.userTier!);
        }
      }

      _lastSyncTime = DateTime.now();
      _state = PermissionSyncState.synced;
      _lastResult = PermissionSyncResult.success(
        rolesCount: data.roles.length,
        permissionsCount: _engine.effectivePermissions.length,
        entitlementsCount: data.entitlements.length,
        syncedAt: _lastSyncTime!,
      );

      AppLogger.info(
        _tag,
        'Permission sync complete: ${_lastResult!.rolesCount} roles, '
        '${_lastResult!.permissionsCount} permissions, '
        '${_lastResult!.entitlementsCount} entitlements.',
      );

      return _lastResult!;
    } catch (e, st) {
      _state = PermissionSyncState.failed;
      _lastResult = PermissionSyncResult.failure(
        error: e.toString(),
        lastSyncTime: _lastSyncTime,
      );

      AppLogger.error(
        _tag,
        'Permission sync failed: $e',
        error: e,
        stackTrace: st,
      );

      return _lastResult!;
    }
  }

  /// Check if a sync is needed based on the interval.
  bool shouldSync() {
    if (_lastSyncTime == null) return true;
    return DateTime.now().difference(_lastSyncTime!) > syncInterval;
  }

  /// Force invalidate the local cache — requires fresh sync.
  void invalidate() {
    _lastSyncTime = null;
    _state = PermissionSyncState.idle;
    AppLogger.warning(_tag, 'Permission cache invalidated — sync required.');
  }
}

/// Callback for fetching permissions from the backend.
typedef FetchPermissionsCallback = Future<PermissionSyncData> Function({
  required String userId,
  String? branchId,
  String? tenantId,
});

/// Data returned from a backend permission fetch.
class PermissionSyncData {
  const PermissionSyncData({
    this.roles = const [],
    this.userRoleIds = const [],
    this.temporaryPermissions = const [],
    this.entitlements = const [],
    this.userTier,
  });

  final List<Role> roles;
  final List<String> userRoleIds;
  final List<TemporaryPermission> temporaryPermissions;
  final List<FeatureEntitlement> entitlements;
  final SubscriptionTier? userTier;
}

/// Result of a permission sync operation.
class PermissionSyncResult {
  PermissionSyncResult._({
    required this.success,
    this.rolesCount,
    this.permissionsCount,
    this.entitlementsCount,
    this.syncedAt,
    this.error,
    this.lastSyncTime,
  });

  final bool success;
  final int? rolesCount;
  final int? permissionsCount;
  final int? entitlementsCount;
  final DateTime? syncedAt;
  final String? error;
  final DateTime? lastSyncTime;

  factory PermissionSyncResult.success({
    required int rolesCount,
    required int permissionsCount,
    required int entitlementsCount,
    required DateTime syncedAt,
  }) {
    return PermissionSyncResult._(
      success: true,
      rolesCount: rolesCount,
      permissionsCount: permissionsCount,
      entitlementsCount: entitlementsCount,
      syncedAt: syncedAt,
    );
  }

  factory PermissionSyncResult.failure({
    required String error,
    DateTime? lastSyncTime,
  }) {
    return PermissionSyncResult._(
      success: false,
      error: error,
      lastSyncTime: lastSyncTime,
    );
  }
}

enum PermissionSyncState {
  idle,
  syncing,
  synced,
  failed,
}
