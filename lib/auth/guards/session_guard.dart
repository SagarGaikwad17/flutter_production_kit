import 'dart:async';
import 'package:flutter_production_kit/auth/session/session_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Session guard — protects service operations (not routes).
///
/// Design rationale:
/// Route guards protect navigation. Session guards protect API calls,
/// background tasks, and service operations that require authentication.
///
/// Usage in a service:
/// ```dart
/// class DataService {
///   final SessionGuard _guard;
///
///   Future<Data> fetchData() async {
///     await _guard.requireAuthenticated();
///     final token = await _guard.getValidToken();
///     // ... make API call with token
///   }
/// }
/// ```
class SessionGuard {
  SessionGuard({required SessionManager sessionManager})
      : _sessionManager = sessionManager;

  static const String _tag = 'SessionGuard';

  final SessionManager _sessionManager;

  /// Require an active authenticated session.
  ///
  /// Throws [SessionGuardException] if not authenticated.
  Future<void> requireAuthenticated() async {
    if (!_sessionManager.isAuthenticated) {
      AppLogger.warning(_tag, 'Session guard: not authenticated.');
      throw SessionGuardException(
        reason: SessionGuardReason.notAuthenticated,
        message: 'User is not authenticated.',
      );
    }
  }

  /// Require a specific minimum role.
  ///
  /// Throws [SessionGuardException] if the user doesn't have the required role.
  Future<void> requireRole(dynamic requiredRole) async {
    await requireAuthenticated();

    if (!_sessionManager.hasRole(requiredRole)) {
      final session = _sessionManager.currentSession;
      AppLogger.warning(
        _tag,
        'Session guard: insufficient role. Required: $requiredRole, '
        'User roles: ${session?.user.roles.map((e) => e.name)}',
      );
      throw SessionGuardException(
        reason: SessionGuardReason.insufficientRole,
        message: 'Insufficient role: required $requiredRole.',
        requiredRole: requiredRole.toString(),
      );
    }
  }

  /// Require any of the specified roles.
  Future<void> requireAnyRole(List<dynamic> roles) async {
    await requireAuthenticated();

    if (!_sessionManager.hasAnyRole(roles.cast())) {
      throw SessionGuardException(
        reason: SessionGuardReason.insufficientRole,
        message: 'User does not have any of the required roles: ${roles.join(', ')}.',
      );
    }
  }

  /// Get a valid access token — refreshes if needed.
  ///
  /// Throws [SessionGuardException] if token cannot be obtained.
  Future<String> getValidToken() async {
    try {
      return await _sessionManager.getAccessToken();
    } catch (e) {
      AppLogger.warning(_tag, 'Session guard: failed to get valid token.', error: e);
      throw SessionGuardException(
        reason: SessionGuardReason.tokenUnavailable,
        message: 'Could not obtain a valid access token.',
        cause: e,
      );
    }
  }

  /// Get the session ID for tracking API calls.
  String? getSessionId() {
    return _sessionManager.currentSession?.sessionId;
  }

  /// Check if the current session has a specific permission.
  bool hasPermission(String permission) {
    final session = _sessionManager.currentSession;
    if (session == null) return false;
    return session.permissions.contains(permission);
  }

  /// Require a specific permission.
  Future<void> requirePermission(String permission) async {
    await requireAuthenticated();

    if (!hasPermission(permission)) {
      throw SessionGuardException(
        reason: SessionGuardReason.insufficientPermission,
        message: 'Missing required permission: $permission.',
      );
    }
  }

  /// Validate the session before performing a sensitive operation.
  ///
  /// Returns true if the session is valid, false otherwise.
  Future<bool> validateForSensitiveOperation() async {
    final result = await _sessionManager.validateSession();

    return switch (result) {
      SessionValidationResult.valid => true,
      SessionValidationResult.sessionRevoked =>
        _onSessionRevoked('Session revoked during sensitive operation.'),
      SessionValidationResult.networkUnavailable =>
        _handleNetworkDuringSensitiveOperation(),
      _ => false,
    };
  }

  bool _onSessionRevoked(String reason) {
    AppLogger.warning(_tag, reason);
    return false;
  }

  bool _handleNetworkDuringSensitiveOperation() {
    final session = _sessionManager.currentSession;
    if (session != null && !session.isTokenExpired) {
      AppLogger.info(_tag, 'Network unavailable — session token still valid, allowing operation.');
      return true;
    }
    AppLogger.warning(_tag, 'Network unavailable and token expired — blocking sensitive operation.');
    return false;
  }
}

enum SessionGuardReason {
  notAuthenticated,
  insufficientRole,
  insufficientPermission,
  tokenUnavailable,
  sessionRevoked,
}

class SessionGuardException implements Exception {
  SessionGuardException({
    required this.reason,
    required this.message,
    this.cause,
    this.requiredRole,
  });

  final SessionGuardReason reason;
  final String message;
  final Object? cause;
  final String? requiredRole;

  @override
  String toString() => 'SessionGuardException($reason): $message';
}
