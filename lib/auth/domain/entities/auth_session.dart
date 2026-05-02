import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/entities/auth_provider_type.dart';

/// Complete auth session — the single source of truth for auth state.
///
/// Design rationale:
/// - Immutable snapshot: the session is rebuilt on every auth change.
///   This eliminates stale-state bugs and race conditions.
/// - [refreshToken] is optional — some providers (e.g., OAuth implicit)
///   don't issue refresh tokens.
/// - [multiDeviceStrategy] controls behavior when the same user logs in
///   from another device.
/// - [lastValidatedAt] tracks when the session was last confirmed with
///   the backend. Critical for offline restore safety.
class AuthSession {
  const AuthSession({
    required this.user,
    required this.tokens,
    required this.providerType,
    required this.sessionId,
    required this.createdAt,
    this.lastValidatedAt,
    this.refreshToken,
    this.deviceFingerprint,
    this.multiDeviceStrategy = MultiDeviceStrategy.allow,
    this.permissions = const [],
  });

  final UserProfile user;
  final TokenPair tokens;
  final AuthProviderType providerType;
  final String sessionId;
  final DateTime createdAt;
  final DateTime? lastValidatedAt;
  final String? refreshToken;
  final String? deviceFingerprint;
  final MultiDeviceStrategy multiDeviceStrategy;
  final List<String> permissions;

  bool get isTokenExpired => tokens.isExpired;

  bool get isTokenExpiringSoon => tokens.isExpiringWithin(const Duration(minutes: 5));

  bool get requiresRefresh => isTokenExpired || isTokenExpiringSoon;

  @override
  String toString() =>
      'AuthSession(user: ${user.email}, provider: ${providerType.name}, sessionId: $sessionId)';
}

/// Strategy for handling multi-device login conflicts.
enum MultiDeviceStrategy {
  /// Allow concurrent sessions on multiple devices.
  allow,

  /// Revoke the oldest session when a new device logs in.
  revokeOldest,

  /// Revoke the new session — only one active device allowed.
  rejectNew,

  /// Allow but notify the user of concurrent sessions.
  allowAndNotify,
}
