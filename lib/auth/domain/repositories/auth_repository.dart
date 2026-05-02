import 'package:flutter_production_kit/auth/domain/entities/auth_session.dart';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';

/// Abstract auth repository — the domain contract for auth operations.
///
/// Design rationale:
/// - Provider-agnostic: implementations can use Firebase, JWT, OAuth, etc.
/// - Every method returns a strongly typed result — no void + exceptions only.
/// - Token refresh is managed by the session engine, NOT called directly here.
abstract class AuthRepository {
  /// Authenticate with email + password.
  Future<AuthLoginResult> loginWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Authenticate with a custom provider token (OAuth, custom backend).
  Future<AuthLoginResult> loginWithProviderToken({
    required String providerToken,
    required String providerId,
  });

  /// Restore an existing session from secure storage.
  Future<AuthRestoreResult> restoreSession();

  /// Refresh the access token using the stored refresh token.
  /// Returns the new token pair.
  Future<AuthRefreshResult> refreshTokens({
    required String refreshToken,
  });

  /// Log out and revoke the current session.
  Future<AuthLogoutResult> logout({
    required String sessionId,
  });

  /// Revoke a specific session by ID (multi-device management).
  Future<void> revokeSession({
    required String sessionId,
  });

  /// Validate the current session with the backend.
  Future<AuthValidationResult> validateSession({
    required String sessionId,
    required String accessToken,
  });

  /// Get the current user profile from the backend.
  Future<UserProfile?> fetchUserProfile({
    required String userId,
  });
}

// ── Result Types ─────────────────────────────────────────────────────────────

sealed class AuthLoginResult {
  const AuthLoginResult();
}

final class AuthLoginSuccess extends AuthLoginResult {
  const AuthLoginSuccess({
    required this.session,
    required this.isNewSession,
  });

  final AuthSession session;
  final bool isNewSession;
}

final class AuthLoginFailure extends AuthLoginResult {
  const AuthLoginFailure({
    required this.reason,
    this.error,
  });

  final AuthLoginFailureReason reason;
  final Object? error;
}

enum AuthLoginFailureReason {
  invalidCredentials,
  accountDisabled,
  emailNotVerified,
  providerUnavailable,
  networkUnavailable,
  suspiciousLogin,
  updateRequired,
  unknown,
}

// ──

sealed class AuthRestoreResult {
  const AuthRestoreResult();
}

final class AuthRestoreSuccess extends AuthRestoreResult {
  const AuthRestoreSuccess({required this.session});

  final AuthSession session;
}

final class AuthRestoreFailure extends AuthRestoreResult {
  const AuthRestoreFailure({
    required this.reason,
    this.error,
  });

  final AuthRestoreFailureReason reason;
  final Object? error;
}

enum AuthRestoreFailureReason {
  noStoredSession,
  tokenExpired,
  sessionRevoked,
  storageCorrupted,
  networkUnavailable,
  multiDeviceConflict,
  unknown,
}

// ──

sealed class AuthRefreshResult {
  const AuthRefreshResult();
}

final class AuthRefreshSuccess extends AuthRefreshResult {
  const AuthRefreshSuccess({required this.newTokens});

  final TokenPair newTokens;
}

final class AuthRefreshFailure extends AuthRefreshResult {
  const AuthRefreshFailure({
    required this.reason,
    this.error,
  });

  final AuthRefreshFailureReason reason;
  final Object? error;
}

enum AuthRefreshFailureReason {
  refreshTokenExpired,
  sessionRevoked,
  networkUnavailable,
  providerUnavailable,
  invalidRefreshToken,
  unknown,
}

// ──

sealed class AuthLogoutResult {
  const AuthLogoutResult();
}

final class AuthLogoutSuccess extends AuthLogoutResult {
  const AuthLogoutSuccess();
}

final class AuthLogoutFailure extends AuthLogoutResult {
  const AuthLogoutFailure({
    required this.reason,
    this.error,
  });

  final AuthLogoutFailureReason reason;
  final Object? error;
}

enum AuthLogoutFailureReason {
  networkUnavailable,
  sessionNotFound,
  providerUnavailable,
  unknown,
}

// ──

sealed class AuthValidationResult {
  const AuthValidationResult();
}

final class AuthValidationSuccess extends AuthValidationResult {
  const AuthValidationSuccess({
    this.sessionStillValid = true,
    this.updatedPermissions,
  });

  final bool sessionStillValid;
  final List<String>? updatedPermissions;
}

final class AuthValidationFailure extends AuthValidationResult {
  const AuthValidationFailure({
    required this.reason,
    this.error,
  });

  final AuthValidationFailureReason reason;
  final Object? error;
}

enum AuthValidationFailureReason {
  sessionRevoked,
  networkUnavailable,
  tokenInvalid,
  unknown,
}
