import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Firebase Auth remote datasource implementation.
///
/// Design rationale:
/// - Uses Firebase Auth SDK directly (no custom backend needed for basic auth).
/// - ID token is used as the access token.
/// - Refresh token is managed internally by Firebase SDK.
/// - For production, consider pairing with Firebase Functions for custom
///   session management and multi-device conflict detection.
class FirebaseAuthDataSource implements AuthRemoteDataSource {
  FirebaseAuthDataSource({
    FirebaseAuth? firebaseAuth,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance;

  static const String _tag = 'FirebaseAuthDataSource';

  final FirebaseAuth _auth;

  @override
  Future<TokenPair> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw GenericAuthException(message: 'Firebase returned null user after login.');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw GenericAuthException(message: 'Failed to obtain Firebase ID token.');
      }

      AppLogger.info(_tag, 'Firebase email login successful for: ${user.email}');

      return TokenPair(
        accessToken: idToken,
        refreshToken: '',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        tokenType: 'Bearer',
      );
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          throw InvalidCredentialsException(
            message: 'Invalid email or password.',
            cause: e,
          ),
        'user-disabled' =>
          throw GenericAuthException(message: 'This account has been disabled.'),
        'too-many-requests' =>
          throw GenericAuthException(message: 'Too many login attempts. Please try again later.'),
        'network-request-failed' =>
          throw const AuthNetworkUnavailableException(
            message: 'Network unavailable during Firebase login.',
          ),
        _ =>
          throw GenericAuthException(message: 'Firebase auth error: ${e.message}', cause: e),
      };
    }
  }

  @override
  Future<TokenPair> loginWithProviderToken({
    required String providerToken,
    required String providerId,
  }) async {
    try {
      final provider = _createOAuthProvider(providerId);
      if (provider == null) {
        throw AuthProviderUnavailableException(
          message: 'Unsupported OAuth provider: $providerId',
          providerType: 'Firebase',
        );
      }

      final credential = await _auth.signInWithPopup(provider);
      final user = credential.user;
      if (user == null) {
        throw GenericAuthException(message: 'Firebase returned null user after OAuth login.');
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        throw GenericAuthException(message: 'Failed to obtain Firebase ID token after OAuth.');
      }

      AppLogger.info(_tag, 'Firebase OAuth login successful via: $providerId');

      return TokenPair(
        accessToken: idToken,
        refreshToken: '',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        tokenType: 'Bearer',
      );
    } on FirebaseAuthException catch (e) {
      throw GenericAuthException(
        message: 'Firebase OAuth error: ${e.message}',
        cause: e,
      );
    }
  }

  @override
  Future<TokenPair> refreshToken({
    required String refreshToken,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const RefreshTokenExpiredException(
          message: 'No Firebase user found for token refresh.',
        );
      }

      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        throw const SessionRevokedException(
          message: 'Firebase user was deleted or disabled.',
        );
      }

      final newIdToken = await refreshedUser.getIdToken(true);
      if (newIdToken == null) {
        throw GenericAuthException(message: 'Failed to refresh Firebase ID token.');
      }

      AppLogger.info(_tag, 'Firebase token refreshed.');

      return TokenPair(
        accessToken: newIdToken,
        refreshToken: '',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        tokenType: 'Bearer',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' || e.code == 'user-disabled') {
        throw const RefreshTokenExpiredException(
          message: 'Firebase token expired or user disabled.',
        );
      }
      throw GenericAuthException(message: 'Firebase refresh error: ${e.message}', cause: e);
    }
  }

  @override
  Future<SessionValidationResponse> validateSession({
    required String sessionId,
    required String accessToken,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const SessionValidationResponse(isValid: false);
    }

    try {
      final idToken = await user.getIdToken(true);
      return SessionValidationResponse(
        isValid: idToken != null,
        multiDeviceCount: null,
      );
    } catch (e) {
      return const SessionValidationResponse(isValid: false);
    }
  }

  @override
  Future<void> revokeSession({required String sessionId}) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  @override
  Future<UserProfile> getUserProfile({required String userId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw GenericAuthException(message: 'No Firebase user available to fetch profile.');
    }

    final roles = _resolveRolesFromClaims(user);

    return UserProfile(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      avatarUrl: user.photoURL,
      roles: roles,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
      isEmailVerified: user.emailVerified,
    );
  }

  @override
  Future<void> logout({required String sessionId}) async {
    await _auth.signOut();
    AppLogger.info(_tag, 'Firebase sign out complete.');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AuthProvider? _createOAuthProvider(String providerId) {
    return switch (providerId.toLowerCase()) {
      'google' => GoogleAuthProvider(),
      'facebook' => FacebookAuthProvider(),
      'apple' => AppleAuthProvider(),
      'twitter' => TwitterAuthProvider(),
      _ => null,
    };
  }

  List<UserRole> _resolveRolesFromClaims(User user) {
    return [UserRole.user];
  }
}
