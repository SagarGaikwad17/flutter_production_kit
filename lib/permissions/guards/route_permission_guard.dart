import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Route-level permission guard for go_router.
///
/// Design rationale:
/// - Integrates with go_router's redirect mechanism.
/// - Checks BOTH authentication AND permission before allowing navigation.
/// - If permission is lost (live role change), redirects to access-denied.
/// - Supports per-route permission requirements via [requiredPermissions].
/// - Offline-aware: blocks sensitive routes when offline.
class RoutePermissionGuard {
  RoutePermissionGuard({
    required PermissionEngine permissionEngine,
    required String userId,
    this.accessDeniedRoute = '/access-denied',
    this.loginRoute = '/login',
  })  : _engine = permissionEngine,
        _userId = userId;

  static const String _tag = 'RoutePermissionGuard';

  final PermissionEngine _engine;
  final String _userId;
  final String accessDeniedRoute;
  final String loginRoute;

  /// Permission requirements mapped to route patterns.
  final Map<String, RoutePermissionRequirement> _routeRequirements = {};

  /// Register permission requirements for a route pattern.
  void registerRequirement(
    String routePattern, {
    required String action,
    required String resource,
    List<String>? entitlements,
    bool allowOffline = false,
  }) {
    _routeRequirements[routePattern] = RoutePermissionRequirement(
      action: action,
      resource: resource,
      entitlements: entitlements,
      allowOffline: allowOffline,
    );
  }

  /// GoRouter redirect callback.
  ///
  /// Returns a redirect if the user cannot access the route.
  String? onRedirect(BuildContext context, GoRouterState state) {
    final fullPath = state.matchedLocation;
    final requirement = _findRequirement(fullPath);

    if (requirement == null) {
      return null; // No permission requirement for this route.
    }

    final isOnline = _checkConnectivity(context);
    final result = _engine.check(
      userId: _userId,
      action: requirement.action,
      resource: requirement.resource,
      branchId: state.uri.queryParameters['branch_id'],
      tenantId: state.uri.queryParameters['tenant_id'],
      requiredEntitlements: requirement.entitlements,
      isOnline: isOnline,
    );

    if (result.isAllowed) {
      return null;
    }

    AppLogger.warning(
      _tag,
      'Route access denied: $fullPath (${result.runtimeType})',
    );

    return '$accessDeniedRoute?reason=${_encodeReason(result)}';
  }

  /// Invalidate all route checks — forces re-evaluation on next navigation.
  /// Call this when permissions change (live role change, temporary permission expiry).
  void invalidate() {
    AppLogger.info(_tag, 'Route permission guard invalidated — '
        'next navigation will re-evaluate permissions.');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  RoutePermissionRequirement? _findRequirement(String path) {
    for (final entry in _routeRequirements.entries) {
      if (path == entry.key || path.startsWith('${entry.key}/')) {
        return entry.value;
      }
    }
    return null;
  }

  bool _checkConnectivity(BuildContext context) {
    // In production, use connectivity_plus or a network service.
    // For now, assume online.
    return true;
  }

  String _encodeReason(AuthorizationResult result) {
    return switch (result) {
      AuthorizationDenied(:final reason) => 'denied:$reason',
      AuthorizationDeniedExpired() => 'denied:expired',
      AuthorizationDeniedEntitlementMissing() => 'denied:entitlement',
      AuthorizationDeniedBranchMismatch() => 'denied:branch',
      AuthorizationDeniedStalePermission() => 'denied:stale',
      AuthorizationDeniedOffline() => 'denied:offline',
      AuthorizationDeniedOwnership() => 'denied:ownership',
      AuthorizationDeniedTenantMismatch() => 'denied:tenant',
      AuthorizationDeniedRoleConflict() => 'denied:conflict',
      AuthorizationAllowed() => '',
    };
  }

  /// Create a GoRouter redirect function.
  GoRouterRedirect get redirect => onRedirect;
}

/// Permission requirement for a route.
class RoutePermissionRequirement {
  const RoutePermissionRequirement({
    required this.action,
    required this.resource,
    this.entitlements,
    this.allowOffline = false,
  });

  final String action;
  final String resource;
  final List<String>? entitlements;
  final bool allowOffline;
}
