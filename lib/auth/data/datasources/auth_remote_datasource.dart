import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';

/// Abstract remote auth datasource.
///
/// Design rationale:
/// Defines the network-level operations for authentication.
/// Concrete implementations handle provider-specific HTTP calls.
abstract class AuthRemoteDataSource {
  /// Authenticate with email + password against the backend.
  Future<TokenPair> loginWithEmail({
    required String email,
    required String password,
  });

  /// Authenticate with a third-party provider token.
  Future<TokenPair> loginWithProviderToken({
    required String providerToken,
    required String providerId,
  });

  /// Exchange a refresh token for a new access token.
  Future<TokenPair> refreshToken({
    required String refreshToken,
  });

  /// Validate the current session with the backend.
  Future<SessionValidationResponse> validateSession({
    required String sessionId,
    required String accessToken,
  });

  /// Revoke a session by ID.
  Future<void> revokeSession({
    required String sessionId,
  });

  /// Fetch the user profile from the backend.
  Future<UserProfile> getUserProfile({
    required String userId,
  });

  /// Logout and invalidate the server-side session.
  Future<void> logout({
    required String sessionId,
  });
}

/// Response from session validation.
class SessionValidationResponse {
  const SessionValidationResponse({
    required this.isValid,
    this.permissions,
    this.revokedAt,
    this.multiDeviceCount,
  });

  final bool isValid;
  final List<String>? permissions;
  final DateTime? revokedAt;
  final int? multiDeviceCount;
}
