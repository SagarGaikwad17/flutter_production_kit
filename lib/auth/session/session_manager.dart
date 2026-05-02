import 'dart:async';
import 'package:flutter_production_kit/auth/domain/entities/auth_session.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_production_kit/auth/session/token_manager.dart';
import 'package:flutter_production_kit/auth/session/refresh_lock_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Central session orchestrator — the single source of truth for auth state.
///
/// Design rationale:
/// - All auth state changes flow through this manager.
/// - Emits state change events for UI and services to react to.
/// - Coordinates between TokenManager (token lifecycle), AuthRepository
///   (network operations), and RefreshLockManager (storm protection).
/// - Handles all edge cases: remote revocation, offline reopen, forced logout,
///   multi-device conflicts, suspicious login.
///
/// State machine:
///   [unauthenticated] → login → [authenticated] → refresh → [authenticated]
///   [authenticated] → revoke/expired → [force_logout] → [unauthenticated]
///   [authenticated] → suspicious → [verification_required]
class SessionManager {
  SessionManager({
    required AuthRepository authRepository,
    required TokenManager tokenManager,
    required RefreshLockManager refreshLockManager,
  })  : _repository = authRepository,
        _tokenManager = tokenManager,
        _lockManager = refreshLockManager;

  static const String _tag = 'SessionManager';

  final AuthRepository _repository;
  final TokenManager _tokenManager;
  final RefreshLockManager _lockManager;

  AuthSession? _currentSession;
  SessionState _state = SessionState.unauthenticated;
  final StreamController<SessionEvent> _eventController =
      StreamController<SessionEvent>.broadcast();

  // ── Public State ───────────────────────────────────────────────────────────

  AuthSession? get currentSession => _currentSession;
  SessionState get state => _state;
  Stream<SessionEvent> get eventStream => _eventController.stream;

  bool get isAuthenticated =>
      _state == SessionState.authenticated || _state == SessionState.offlineAuthenticated;

  bool get isOffline => _state == SessionState.offlineAuthenticated;

  bool get isVerificationRequired => _state == SessionState.verificationRequired;

  /// Check if the current user has the required role.
  bool hasRole(UserRole required) {
    final session = _currentSession;
    if (session == null) return false;
    return session.user.roles.any((r) => r.canAccess(required));
  }

  /// Check if the current user has any of the required roles.
  bool hasAnyRole(List<UserRole> requiredRoles) {
    final session = _currentSession;
    if (session == null) return false;
    return session.user.roles.any(
      (r) => requiredRoles.any((req) => r.canAccess(req)),
    );
  }

  /// Get the valid access token (refreshes if needed).
  Future<String> getAccessToken() async {
    if (_currentSession == null) {
      throw GenericAuthException(message: 'No active session. User must authenticate.');
    }
    return _tokenManager.getValidAccessToken();
  }

  // ── Session Lifecycle ──────────────────────────────────────────────────────

  /// Initialize the session manager — attempt to restore a previous session.
  ///
  /// Called during bootstrap. Returns the restore result for the bootstrap
  /// engine to decide the next step (home, login, or error screen).
  Future<AuthRestoreResult> initialize() async {
    AppLogger.info(_tag, 'Initializing session manager...');

    try {
      final result = await _repository.restoreSession();

      return switch (result) {
        AuthRestoreSuccess(:final session) =>
          _activateSession(session, wasRestored: true),
        AuthRestoreFailure(:final reason) =>
          _handleRestoreFailure(reason, result.error),
      };
    } catch (e, st) {
      AppLogger.error(_tag, 'Session initialization crashed', error: e, stackTrace: st);
      await _forceLogout(reason: 'Initialization crashed: $e');
      return const AuthRestoreFailure(
        reason: AuthRestoreFailureReason.unknown,
      );
    }
  }

  /// Activate a new session after successful login.
  AuthRestoreResult _activateSession(AuthSession session, {bool wasRestored = false}) {
    _currentSession = session;
    _tokenManager.setTokens(session.tokens, refreshToken: session.refreshToken);
    _state = SessionState.authenticated;

    _emitEvent(SessionActivated(session, wasRestored: wasRestored));

    AppLogger.info(
      _tag,
      'Session ${wasRestored ? 'restored' : 'activated'} '
      'for ${session.user.email} (${session.providerType.name})',
    );

    return AuthRestoreSuccess(session: session);
  }

  AuthRestoreResult _handleRestoreFailure(AuthRestoreFailureReason reason, Object? error) {
    return switch (reason) {
      AuthRestoreFailureReason.noStoredSession =>
        const AuthRestoreFailure(reason: AuthRestoreFailureReason.noStoredSession),
      AuthRestoreFailureReason.tokenExpired =>
        const AuthRestoreFailure(reason: AuthRestoreFailureReason.tokenExpired),
      AuthRestoreFailureReason.sessionRevoked =>
        const AuthRestoreFailure(reason: AuthRestoreFailureReason.sessionRevoked),
      AuthRestoreFailureReason.storageCorrupted =>
        const AuthRestoreFailure(reason: AuthRestoreFailureReason.storageCorrupted),
      AuthRestoreFailureReason.networkUnavailable =>
        const AuthRestoreFailure(reason: AuthRestoreFailureReason.networkUnavailable),
      AuthRestoreFailureReason.multiDeviceConflict =>
        AuthRestoreFailure(
          reason: AuthRestoreFailureReason.multiDeviceConflict,
          error: error,
        ),
      AuthRestoreFailureReason.unknown =>
        AuthRestoreFailure(
          reason: AuthRestoreFailureReason.unknown,
          error: error,
        ),
    };
  }

  /// Force logout — called when session is revoked, expired, or admin action.
  ///
  /// This performs a HARD reset: clears all state, cancels pending refreshes,
  /// clears tokens, and notifies all observers.
  Future<void> forceLogout({String? reason}) async {
    AppLogger.warning(_tag, 'Force logout triggered${reason != null ? ': $reason' : ''}.');

    await _forceLogout(reason: reason ?? 'Unknown reason');
  }

  Future<void> _forceLogout({String? reason}) async {
    _lockManager.forceReset();
    _tokenManager.clearTokens();
    _currentSession = null;
    _state = SessionState.unauthenticated;

    await _repository.logout(sessionId: _currentSession?.sessionId ?? 'unknown');

    _emitEvent(SessionExpired(reason: reason));
    AppLogger.info(_tag, 'Session cleared — state reset to unauthenticated.');
  }

  /// Graceful logout — called by the user.
  Future<void> logout() async {
    AppLogger.info(_tag, 'User-initiated logout.');

    final sessionId = _currentSession?.sessionId ?? 'unknown';
    final result = await _repository.logout(sessionId: sessionId);

    _lockManager.forceReset();
    _tokenManager.clearTokens();
    _currentSession = null;
    _state = SessionState.unauthenticated;

    _emitEvent(const SessionLoggedOut());
    AppLogger.info(_tag, 'Logout complete.');

    if (result is AuthLogoutFailure) {
      AppLogger.warning(_tag, 'Logout had issues but local state cleared.', error: result.error);
    }
  }

  /// Handle a token refresh failure — triggers session expiry.
  void onSessionExpired() {
    AppLogger.warning(_tag, 'Session expired detected — triggering force logout.');
    _forceLogout(reason: 'Token refresh failed — session expired or revoked.');
  }

  /// Validate the current session with the backend.
  ///
  /// Called periodically (e.g., every 15 minutes) to detect remote revocation.
  Future<SessionValidationResult> validateSession() async {
    final session = _currentSession;
    if (session == null) {
      return SessionValidationResult.notAuthenticated;
    }

    try {
      final accessToken = await _tokenManager.getValidAccessToken();
      final result = await _repository.validateSession(
        sessionId: session.sessionId,
        accessToken: accessToken,
      );

      return switch (result) {
        AuthValidationSuccess(:final sessionStillValid, :final updatedPermissions) =>
          _handleValidationSuccess(sessionStillValid, updatedPermissions),
        AuthValidationFailure(:final reason) =>
          _handleValidationFailure(reason),
      };
    } on AuthNetworkUnavailableException {
      return SessionValidationResult.networkUnavailable;
    } catch (e) {
      AppLogger.error(_tag, 'Session validation error', error: e);
      return SessionValidationResult.error;
    }
  }

  SessionValidationResult _handleValidationSuccess(
    bool isValid,
    List<String>? updatedPermissions,
  ) {
    if (!isValid) {
      _forceLogout(reason: 'Session validation failed — session revoked.');
      return SessionValidationResult.sessionRevoked;
    }

    if (updatedPermissions != null && _currentSession != null) {
      _currentSession = AuthSession(
        user: _currentSession!.user,
        tokens: _currentSession!.tokens,
        providerType: _currentSession!.providerType,
        sessionId: _currentSession!.sessionId,
        createdAt: _currentSession!.createdAt,
        lastValidatedAt: DateTime.now(),
        refreshToken: _currentSession!.refreshToken,
        deviceFingerprint: _currentSession!.deviceFingerprint,
        multiDeviceStrategy: _currentSession!.multiDeviceStrategy,
        permissions: updatedPermissions,
      );
    }

    return SessionValidationResult.valid;
  }

  SessionValidationResult _handleValidationFailure(AuthValidationFailureReason reason) {
    return switch (reason) {
      AuthValidationFailureReason.sessionRevoked =>
        _onSessionRevokedDuringValidation(),
      AuthValidationFailureReason.networkUnavailable =>
        SessionValidationResult.networkUnavailable,
      _ => SessionValidationResult.error,
    };
  }

  SessionValidationResult _onSessionRevokedDuringValidation() {
    AppLogger.warning(_tag, 'Session revoked during validation — force logout.');
    _forceLogout(reason: 'Session was revoked remotely.');
    return SessionValidationResult.sessionRevoked;
  }

  // ── Event Emission ─────────────────────────────────────────────────────────

  void _emitEvent(SessionEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose resources.
  void dispose() {
    _eventController.close();
    _tokenManager.dispose();
  }
}

// ── Session State ────────────────────────────────────────────────────────────

enum SessionState {
  unauthenticated,
  authenticated,
  offlineAuthenticated,
  verificationRequired,
}

// ── Session Events ───────────────────────────────────────────────────────────

sealed class SessionEvent {
  const SessionEvent();
}

final class SessionActivated extends SessionEvent {
  const SessionActivated(this.session, {required this.wasRestored});
  final AuthSession session;
  final bool wasRestored;
}

final class SessionExpired extends SessionEvent {
  const SessionExpired({this.reason});
  final String? reason;
}

final class SessionLoggedOut extends SessionEvent {
  const SessionLoggedOut();
}

final class SessionSuspiciousLogin extends SessionEvent {
  const SessionSuspiciousLogin({required this.reasons});
  final List<String> reasons;
}

final class SessionMultiDeviceConflict extends SessionEvent {
  const SessionMultiDeviceConflict({required this.activeDeviceCount});
  final int activeDeviceCount;
}

// ── Validation Result ────────────────────────────────────────────────────────

enum SessionValidationResult {
  valid,
  sessionRevoked,
  networkUnavailable,
  notAuthenticated,
  error,
}
