/// Sealed auth exception hierarchy.
///
/// Design rationale:
/// Every auth failure mode has a distinct type. Call sites MUST handle
/// each case explicitly — no swallowing errors with generic Exception.
///
/// Each exception carries enough context for the UI to show the correct
/// message and for the session engine to take the right recovery action.

sealed class AuthException implements Exception {
  const AuthException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? '\nCaused by: $cause' : ''}';
}

/// Generic auth exception for uncategorized failures.
/// Use specific exception types whenever possible.
final class GenericAuthException extends AuthException {
  const GenericAuthException({
    required super.message,
    super.cause,
  });
}

/// Credentials rejected by the auth provider.
final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException({
    required super.message,
    super.cause,
    this.hint,
  });

  final String? hint;
}

/// Access token has expired and refresh is required.
final class TokenExpiredException extends AuthException {
  const TokenExpiredException({
    required super.message,
    super.cause,
  });
}

/// Refresh token has also expired — full re-authentication required.
final class RefreshTokenExpiredException extends AuthException {
  const RefreshTokenExpiredException({
    required super.message,
    super.cause,
    this.sessionId,
  });

  final String? sessionId;
}

/// Session was revoked remotely (password change, admin action, etc.).
final class SessionRevokedException extends AuthException {
  const SessionRevokedException({
    required super.message,
    super.cause,
    this.revokedAt,
    this.reason,
  });

  final DateTime? revokedAt;
  final String? reason;
}

/// Network unavailable during an auth operation that requires it.
final class AuthNetworkUnavailableException extends AuthException {
  const AuthNetworkUnavailableException({
    required super.message,
    super.cause,
  });
}

/// Suspicious login detected — additional verification required.
final class SuspiciousLoginException extends AuthException {
  const SuspiciousLoginException({
    required super.message,
    super.cause,
    this.reasons = const [],
  });

  final List<String> reasons;
}

/// Auth provider failed to initialize or is unavailable.
final class AuthProviderUnavailableException extends AuthException {
  const AuthProviderUnavailableException({
    required super.message,
    required this.providerType,
    super.cause,
  });

  final String providerType;
}

/// Secure storage is corrupted or inaccessible.
final class AuthStorageCorruptedException extends AuthException {
  const AuthStorageCorruptedException({
    required super.message,
    super.cause,
    this.storageKey,
  });

  final String? storageKey;
}

/// Multi-device conflict detected — session policy violation.
final class MultiDeviceConflictException extends AuthException {
  const MultiDeviceConflictException({
    required super.message,
    super.cause,
    this.activeDeviceCount,
  });

  final int? activeDeviceCount;
}

/// Forced logout initiated by backend or admin action.
final class ForcedLogoutException extends AuthException {
  const ForcedLogoutException({
    required super.message,
    super.cause,
    this.reason,
  });

  final String? reason;
}

/// Backend requires a forced app update before auth can proceed.
final class AuthUpdateRequiredException extends AuthException {
  const AuthUpdateRequiredException({
    required super.message,
    super.cause,
    this.minimumVersion,
  });

  final String? minimumVersion;
}
