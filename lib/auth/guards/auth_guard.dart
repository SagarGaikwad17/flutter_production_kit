import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_production_kit/auth/session/session_manager.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Route guard for go_router — protects routes based on auth state.
///
/// Design rationale:
/// - NOT a UI-only check: validates actual session state from [SessionManager].
/// - Handles three cases: authenticated (pass), unauthenticated (redirect to login),
///   and verification-required (redirect to verification screen).
/// - Supports role-based access — routes can require a minimum role level.
/// - Offline-aware: allows access to certain routes when in offline-authenticated state.
class AuthRouteGuard {
  AuthRouteGuard({
    required SessionManager sessionManager,
    required String loginRoute,
    required String verificationRoute,
    this.offlineAllowedRoutes = const [],
  })  : _sessionManager = sessionManager,
        _loginRoute = loginRoute,
        _verificationRoute = verificationRoute;

  static const String _tag = 'AuthRouteGuard';

  final SessionManager _sessionManager;
  final String _loginRoute;
  final String _verificationRoute;
  final List<String> offlineAllowedRoutes;

  /// GoRouter redirect callback.
  ///
  /// Returns a redirect String if the user cannot access the route,
  /// or null if access is granted.
  String? onRedirect(BuildContext context, GoRouterState state) {
    final fullPath = state.matchedLocation;
    final sessionState = _sessionManager.state;
    final session = _sessionManager.currentSession;

    AppLogger.debug(_tag, 'Route guard checking: $fullPath (state: ${sessionState.name})');

    // Allow unauthenticated access to login and public routes.
    if (_isPublicRoute(fullPath)) {
      if (_sessionManager.isAuthenticated) {
        AppLogger.debug(_tag, 'Authenticated user on public route — redirecting to home.');
        return '/home';
      }
      return null;
    }

    // Check authentication.
    if (!_sessionManager.isAuthenticated) {
      AppLogger.info(_tag, 'Unauthenticated — redirecting to login from: $fullPath');
      return '$_loginRoute?redirect=$fullPath';
    }

    // Verification required (suspicious login, MFA pending, etc.).
    if (_sessionManager.isVerificationRequired) {
      AppLogger.info(_tag, 'Verification required — redirecting from: $fullPath');
      return _verificationRoute;
    }

    // Role-based access check.
    final requiredRole = _getRequiredRole(fullPath);
    if (requiredRole != null && session != null) {
      if (!session.user.roles.any((r) => r.canAccess(requiredRole))) {
        AppLogger.warning(
          _tag,
          'Insufficient role for $fullPath — user roles: ${session.user.roles.map((e) => e.name)}',
        );
        return '/access-denied';
      }
    }

    // Offline check — some routes may be blocked in offline mode.
    if (_sessionManager.isOffline && !offlineAllowedRoutes.contains(fullPath)) {
      AppLogger.info(_tag, 'Offline mode — blocking route: $fullPath');
      return '/offline';
    }

    return null;
  }

  /// Async route guard — validates token before allowing navigation.
  ///
  /// Use this for sensitive routes that need a valid access token
  /// (not just a stored session).
  Future<String?> onRedirectAsync(BuildContext context, GoRouterState state) async {
    if (!_sessionManager.isAuthenticated) {
      return onRedirect(context, state);
    }

    try {
      await _sessionManager.getAccessToken();
    } catch (e) {
      AppLogger.warning(_tag, 'Token validation failed for route: ${state.matchedLocation}', error: e);
      return '$_loginRoute?redirect=${state.matchedLocation}';
    }

    return onRedirect(context, state);
  }

  // ── Route Classification ───────────────────────────────────────────────────

  static const _publicRoutes = [
    '/login',
    '/register',
    '/forgot-password',
    '/verify-email',
    '/access-denied',
    '/offline',
    '/update-required',
    '/maintenance',
  ];

  static const _adminRoutes = [
    '/admin',
    '/admin/users',
    '/admin/settings',
    '/admin/logs',
  ];

  static const _moderatorRoutes = [
    '/moderate',
    '/moderate/reports',
    '/moderate/content',
  ];

  bool _isPublicRoute(String path) {
    return _publicRoutes.any((route) => path == route || path.startsWith('$route/'));
  }

  UserRole? _getRequiredRole(String path) {
    if (_adminRoutes.any((route) => path == route || path.startsWith('$route/'))) {
      return UserRole.admin;
    }
    if (_moderatorRoutes.any((route) => path == route || path.startsWith('$route/'))) {
      return UserRole.moderator;
    }
    return null;
  }

  /// Register this guard with a GoRouter instance.
  ///
  /// Usage:
  /// ```dart
  /// GoRouter(
  ///   redirect: (context, state) => authGuard.onRedirect(context, state),
  ///   routes: [...],
  /// );
  /// ```
  GoRouterRedirect get redirect => onRedirect;
}
