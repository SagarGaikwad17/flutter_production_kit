/// Signing result — outcome of a release signing operation.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No sensitive data in results (no keys, no passwords).
/// - Audit-safe — results can be logged without leaking secrets.
/// - Platform-specific signing tracked separately.
///
/// Outcomes:
/// - SigningSuccess: artifact signed successfully.
/// - SigningFailure: signing failed (reason provided, no secrets).
/// - KeyNotFound: signing key not found for environment.
/// - KeyExpired: signing key has expired.
/// - EnvironmentMismatch: signing key doesn't match target environment.
/// - SecretAccessDenied: unauthorized access to signing credentials.
sealed class SigningResult {
  const SigningResult({required this.releaseId, required this.platform});
  final String releaseId;
  final String platform;

  bool get isSuccess => this is SigningSuccess;
}

/// Signing completed successfully.
final class SigningSuccess extends SigningResult {
  const SigningSuccess({
    required super.releaseId,
    required super.platform,
    required this.checksum,
    required this.signedAt,
    this.keyAlias,
  });
  final String checksum;
  final DateTime signedAt;
  final String? keyAlias;
}

/// Signing failed.
final class SigningFailure extends SigningResult {
  const SigningFailure({
    required super.releaseId,
    required super.platform,
    required this.reason,
    this.errorCode,
  });
  final String reason;
  final String? errorCode;
}

/// Signing key not found.
final class KeyNotFound extends SigningResult {
  const KeyNotFound({
    required super.releaseId,
    required super.platform,
    required this.environment,
    this.expectedKeyAlias,
  });
  final String environment;
  final String? expectedKeyAlias;
}

/// Signing key has expired.
final class KeyExpired extends SigningResult {
  const KeyExpired({
    required super.releaseId,
    required super.platform,
    required this.expiredAt,
    this.keyAlias,
  });
  final DateTime expiredAt;
  final String? keyAlias;
}

/// Environment mismatch during signing.
final class SigningEnvironmentMismatch extends SigningResult {
  const SigningEnvironmentMismatch({
    required super.releaseId,
    required super.platform,
    required this.releaseEnvironment,
    required this.keyEnvironment,
  });
  final String releaseEnvironment;
  final String keyEnvironment;
}

/// Secret access denied.
final class SecretAccessDenied extends SigningResult {
  const SecretAccessDenied({
    required super.releaseId,
    required super.platform,
    required this.requestedSecret,
    this.requesterId,
  });
  final String requestedSecret;
  final String? requesterId;
}
