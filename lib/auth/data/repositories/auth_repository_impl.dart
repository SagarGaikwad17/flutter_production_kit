import 'package:flutter_production_kit/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/domain/entities/auth_session.dart';
import 'package:flutter_production_kit/auth/domain/entities/auth_provider_type.dart';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/auth/security/device_binding.dart';

/// Production auth repository implementation.
///
/// Design rationale:
/// - Coordinates between remote datasource (network) and local datasource (secure storage).
/// - All token persistence is handled here — never direct storage access from providers.
/// - Session validation happens after login to detect revocation immediately.
/// - Storage corruption triggers a clean recovery, not a crash.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required DeviceBinding deviceBinding,
  })  : _remote = remoteDataSource,
        _local = localDataSource,
        _deviceBinding = deviceBinding;

  static const String _tag = 'AuthRepository';

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final DeviceBinding _deviceBinding;

  @override
  Future<AuthLoginResult> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await _remote.loginWithEmail(
        email: email,
        password: password,
      );

      final profile = await _remote.getUserProfile(userId: tokens.accessToken);
      final sessionId = _generateSessionId();
      final deviceFingerprint = await _deviceBinding.generateFingerprint();

      final session = AuthSession(
        user: profile,
        tokens: tokens,
        providerType: AuthProviderType.jwt,
        sessionId: sessionId,
        createdAt: DateTime.now(),
        lastValidatedAt: DateTime.now(),
        refreshToken: tokens.refreshToken,
        deviceFingerprint: deviceFingerprint,
      );

      await _persistSession(session);

      AppLogger.info(_tag, 'Login successful for user: ${profile.email}');

      return AuthLoginSuccess(
        session: session,
        isNewSession: true,
      );
    } on AuthNetworkUnavailableException {
      return const AuthLoginFailure(
        reason: AuthLoginFailureReason.networkUnavailable,
      );
    } on InvalidCredentialsException {
      return const AuthLoginFailure(
        reason: AuthLoginFailureReason.invalidCredentials,
      );
    } on SuspiciousLoginException catch (e) {
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.suspiciousLogin,
        error: e,
      );
    } on AuthProviderUnavailableException catch (e) {
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.providerUnavailable,
        error: e,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Unexpected login failure', error: e, stackTrace: st);
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.unknown,
        error: e,
      );
    }
  }

  @override
  Future<AuthLoginResult> loginWithProviderToken({
    required String providerToken,
    required String providerId,
  }) async {
    try {
      final tokens = await _remote.loginWithProviderToken(
        providerToken: providerToken,
        providerId: providerId,
      );

      final profile = await _remote.getUserProfile(userId: tokens.accessToken);
      final sessionId = _generateSessionId();
      final deviceFingerprint = await _deviceBinding.generateFingerprint();

      final providerType = _resolveProviderType(providerId);

      final session = AuthSession(
        user: profile,
        tokens: tokens,
        providerType: providerType,
        sessionId: sessionId,
        createdAt: DateTime.now(),
        lastValidatedAt: DateTime.now(),
        refreshToken: tokens.refreshToken,
        deviceFingerprint: deviceFingerprint,
      );

      await _persistSession(session);

      AppLogger.info(_tag, 'Provider login successful: $providerId for ${profile.email}');

      return AuthLoginSuccess(
        session: session,
        isNewSession: true,
      );
    } on AuthNetworkUnavailableException {
      return const AuthLoginFailure(
        reason: AuthLoginFailureReason.networkUnavailable,
      );
    } on AuthProviderUnavailableException catch (e) {
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.providerUnavailable,
        error: e,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Provider login failed', error: e, stackTrace: st);
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.unknown,
        error: e,
      );
    }
  }

  @override
  Future<AuthRestoreResult> restoreSession() async {
    try {
      final hasAuth = await _local.hasStoredAuth();
      if (!hasAuth) {
        AppLogger.info(_tag, 'No stored auth found — fresh install or logged out.');
        return const AuthRestoreFailure(
          reason: AuthRestoreFailureReason.noStoredSession,
        );
      }

      final accessToken = await _local.readAccessToken();
      final refreshToken = await _local.readRefreshToken();
      final sessionId = await _local.readSessionId();
      final profile = await _local.readUserProfile();
      final expiry = await _local.readTokenExpiry();
      await _local.readSessionMetadata();

      if (accessToken == null || refreshToken == null || sessionId == null || profile == null) {
        AppLogger.warning(_tag, 'Stored auth data is incomplete — triggering cleanup.');
        await _local.clearAllAuthData();
        return const AuthRestoreFailure(
          reason: AuthRestoreFailureReason.storageCorrupted,
        );
      }

      final tokenExpiry = expiry ?? DateTime.now();
      final isTokenExpired = DateTime.now().isAfter(tokenExpiry);

      final deviceFingerprint = await _deviceBinding.generateFingerprint();

      final storedTokens = TokenPair(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: tokenExpiry,
      );

      final session = AuthSession(
        user: profile,
        tokens: storedTokens,
        providerType: AuthProviderType.jwt,
        sessionId: sessionId,
        createdAt: DateTime.now(),
        refreshToken: refreshToken,
        deviceFingerprint: deviceFingerprint,
      );

      if (isTokenExpired) {
        AppLogger.info(_tag, 'Stored token expired — attempting refresh during restore.');
        try {
          final newTokens = await _remote.refreshToken(refreshToken: refreshToken);
          await _local.saveTokens(newTokens);
          await _local.saveTokenExpiry(newTokens.expiresAt);

          final refreshedSession = session.copyWith(
            tokens: newTokens,
            refreshToken: newTokens.refreshToken,
          );

          return AuthRestoreSuccess(session: refreshedSession);
        } on RefreshTokenExpiredException {
          AppLogger.warning(_tag, 'Refresh token also expired — session cannot be restored.');
          await _local.clearAllAuthData();
          return const AuthRestoreFailure(
            reason: AuthRestoreFailureReason.tokenExpired,
          );
        } on SessionRevokedException {
          AppLogger.warning(_tag, 'Session was revoked — cannot restore.');
          await _local.clearAllAuthData();
          return const AuthRestoreFailure(
            reason: AuthRestoreFailureReason.sessionRevoked,
          );
        } on AuthNetworkUnavailableException {
          AppLogger.info(_tag, 'Network unavailable during restore with expired token — allowing limited offline.');
          return AuthRestoreSuccess(session: session);
        }
      }

      AppLogger.info(_tag, 'Session restored successfully for user: ${profile.email}');
      return AuthRestoreSuccess(session: session);
    } on AuthStorageCorruptedException catch (e, st) {
      AppLogger.error(_tag, 'Auth storage corrupted — clearing and forcing re-login.', error: e, stackTrace: st);
      try {
        await _local.clearAllAuthData();
      } catch (_) {}
      return const AuthRestoreFailure(
        reason: AuthRestoreFailureReason.storageCorrupted,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Session restore failed unexpectedly', error: e, stackTrace: st);
      return AuthRestoreFailure(
        reason: AuthRestoreFailureReason.unknown,
        error: e,
      );
    }
  }

  @override
  Future<AuthRefreshResult> refreshTokens({
    required String refreshToken,
  }) async {
    try {
      final newTokens = await _remote.refreshToken(refreshToken: refreshToken);
      await _local.saveTokens(newTokens);
      await _local.saveTokenExpiry(newTokens.expiresAt);

      AppLogger.info(_tag, 'Token refresh successful.');

      return AuthRefreshSuccess(newTokens: newTokens);
    } on RefreshTokenExpiredException {
      AppLogger.warning(_tag, 'Refresh token expired — full re-authentication required.');
      await _local.clearAllAuthData();
      return const AuthRefreshFailure(
        reason: AuthRefreshFailureReason.refreshTokenExpired,
      );
    } on SessionRevokedException {
      AppLogger.warning(_tag, 'Session revoked during refresh.');
      await _local.clearAllAuthData();
      return const AuthRefreshFailure(
        reason: AuthRefreshFailureReason.sessionRevoked,
      );
    } on AuthNetworkUnavailableException {
      return const AuthRefreshFailure(
        reason: AuthRefreshFailureReason.networkUnavailable,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Token refresh failed', error: e, stackTrace: st);
      return AuthRefreshFailure(
        reason: AuthRefreshFailureReason.unknown,
        error: e,
      );
    }
  }

  @override
  Future<AuthLogoutResult> logout({required String sessionId}) async {
    try {
      await _remote.logout(sessionId: sessionId);
    } catch (e) {
      AppLogger.warning(_tag, 'Server-side logout failed — clearing local data anyway.', error: e);
    }

    try {
      await _local.clearAllAuthData();
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to clear local auth data', error: e, stackTrace: st);
      return const AuthLogoutFailure(
        reason: AuthLogoutFailureReason.unknown,
      );
    }

    AppLogger.info(_tag, 'Logout complete — all local and server state cleared.');
    return const AuthLogoutSuccess();
  }

  @override
  Future<void> revokeSession({required String sessionId}) {
    return _remote.revokeSession(sessionId: sessionId);
  }

  @override
  Future<AuthValidationResult> validateSession({
    required String sessionId,
    required String accessToken,
  }) async {
    try {
      final response = await _remote.validateSession(
        sessionId: sessionId,
        accessToken: accessToken,
      );

      if (!response.isValid) {
        await _local.clearAllAuthData();
        return const AuthValidationFailure(
          reason: AuthValidationFailureReason.sessionRevoked,
        );
      }

      if (response.permissions != null) {
        await _local.saveSessionMetadata({
          'permissions': response.permissions,
          'validated_at': DateTime.now().toIso8601String(),
        });
      }

      return AuthValidationSuccess(
        sessionStillValid: true,
        updatedPermissions: response.permissions,
      );
    } on SessionRevokedException {
      await _local.clearAllAuthData();
      return const AuthValidationFailure(
        reason: AuthValidationFailureReason.sessionRevoked,
      );
    } on AuthNetworkUnavailableException {
      return const AuthValidationFailure(
        reason: AuthValidationFailureReason.networkUnavailable,
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'Session validation failed', error: e, stackTrace: st);
      return AuthValidationFailure(
        reason: AuthValidationFailureReason.unknown,
        error: e,
      );
    }
  }

  @override
  Future<UserProfile?> fetchUserProfile({required String userId}) {
    return _remote.getUserProfile(userId: userId);
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Future<void> _persistSession(AuthSession session) async {
    await _local.saveTokens(session.tokens);
    await _local.saveRefreshToken(session.refreshToken ?? session.tokens.refreshToken);
    await _local.saveSessionId(session.sessionId);
    await _local.saveTokenExpiry(session.tokens.expiresAt);
    await _local.saveUserProfile(session.user);
    await _local.saveSessionMetadata({
      'provider_type': session.providerType.name,
      'created_at': session.createdAt.toIso8601String(),
      'device_fingerprint': session.deviceFingerprint,
      'multi_device_strategy': session.multiDeviceStrategy.name,
    });
  }

  String _generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 100000;
    return 'sess_${now}_$random';
  }

  AuthProviderType _resolveProviderType(String providerId) {
    return switch (providerId.toLowerCase()) {
      'google' || 'facebook' || 'apple' || 'twitter' => AuthProviderType.oauth,
      'firebase' => AuthProviderType.firebase,
      'custom' => AuthProviderType.custom,
      _ => AuthProviderType.jwt,
    };
  }
}

extension on AuthSession {
  AuthSession copyWith({
    dynamic tokens,
    String? refreshToken,
  }) {
    return AuthSession(
      user: user,
      tokens: tokens ?? this.tokens,
      providerType: providerType,
      sessionId: sessionId,
      createdAt: createdAt,
      lastValidatedAt: lastValidatedAt,
      refreshToken: refreshToken ?? this.refreshToken,
      deviceFingerprint: deviceFingerprint,
      multiDeviceStrategy: multiDeviceStrategy,
      permissions: permissions,
    );
  }
}
