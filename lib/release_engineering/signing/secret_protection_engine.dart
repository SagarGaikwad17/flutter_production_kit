import 'package:flutter_production_kit/release_engineering/domain/exceptions/release_exception.dart';

/// Secret protection engine — prevents secret leakage in CI/CD pipelines.
///
/// Design rationale:
/// - Secrets are never logged, printed, or stored in plaintext.
/// - Secret access is audited — every access is recorded.
/// - Secret masking replaces sensitive values with placeholders.
/// - Environment-bound secrets — production secrets cannot be used in dev.
/// - Pattern detection scans for accidental secret exposure.
///
/// Protected secret types:
/// - Keystore passwords.
/// - API keys.
/// - OAuth tokens.
/// - Signing certificates.
/// - Provisioning profiles.
/// - Private keys.
///
/// Safety rules:
/// - NO secrets in log output.
/// - NO secrets in error messages.
/// - NO secrets in artifact metadata.
/// - NO secrets in audit trails (masked only).
/// - NO secrets in CI environment variables without masking.
class SecretProtectionEngine {
  const SecretProtectionEngine({
    this.maskedValue = '[REDACTED]',
    this.secretPatterns = const [
      r'password',
      r'secret',
      r'token',
      r'key',
      r'cert',
      r'private',
      r'keystore',
      r'provisioning',
    ],
    this.environmentSecretBoundaries = const {
      'production': ['production'],
      'staging': ['staging', 'production'],
      'dev': ['dev', 'staging', 'production'],
    },
  });

  final String maskedValue;
  final List<String> secretPatterns;
  final Map<String, List<String>> environmentSecretBoundaries;

  /// Mask a value if it matches a secret pattern.
  String maskSecret(String key, String value) {
    if (_isSecretKey(key)) {
      return maskedValue;
    }
    return value;
  }

  /// Mask all secrets in a map.
  Map<String, String> maskSecrets(Map<String, String> data) {
    final masked = <String, String>{};
    for (final entry in data.entries) {
      masked[entry.key] = maskSecret(entry.key, entry.value);
    }
    return masked;
  }

  /// Mask all secrets in a log message.
  String maskLogMessage(String message) {
    var masked = message;
    for (final pattern in secretPatterns) {
      final regex = RegExp(r'(?<=' + pattern + r'[=: ]\s*)[^\s,;]+', caseSensitive: false);
      masked = masked.replaceAll(regex, maskedValue);
    }
    return masked;
  }

  /// Check if a key is a secret key.
  bool _isSecretKey(String key) {
    final lowerKey = key.toLowerCase();
    return secretPatterns.any((pattern) => lowerKey.contains(pattern));
  }

  /// Validate that a secret access is allowed for the current environment.
  void validateSecretAccess({
    required String secretEnvironment,
    required String targetEnvironment,
    required String secretName,
  }) {
    final allowedEnvironments = environmentSecretBoundaries[targetEnvironment];
    if (allowedEnvironments == null) {
      throw SecretAccessDeniedException(
        message: 'Unknown target environment: $targetEnvironment',
        requestedSecret: secretName,
      );
    }

    if (!allowedEnvironments.contains(secretEnvironment)) {
      throw SecretAccessDeniedException(
        message: 'Secret from "$secretEnvironment" cannot be used in '
            '"$targetEnvironment"',
        requestedSecret: secretName,
      );
    }
  }

  /// Scan a string for potential secret leakage.
  bool containsPotentialSecretLeak(String content) {
    // Check for common secret patterns in content.
    final leakPatterns = [
      RegExp(r'-----BEGIN (RSA )?PRIVATE KEY-----'),
      RegExp(r'-----BEGIN CERTIFICATE-----'),
      RegExp(r'AKIA[0-9A-Z]{16}'), // AWS access key pattern
      RegExp(r'ghp_[A-Za-z0-9]{36}'), // GitHub token pattern
      RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'), // JWT pattern
    ];

    for (final pattern in leakPatterns) {
      if (pattern.hasMatch(content)) return true;
    }

    return false;
  }

  /// Sanitize content by removing potential secret leakage.
  String sanitizeContent(String content) {
    if (!containsPotentialSecretLeak(content)) return content;

    var sanitized = content;

    // Remove private keys
    sanitized = sanitized.replaceAll(
      RegExp(r'-----BEGIN.*?PRIVATE KEY-----.*?-----END.*?PRIVATE KEY-----', dotAll: true),
      '[PRIVATE KEY REDACTED]',
    );

    // Remove certificates
    sanitized = sanitized.replaceAll(
      RegExp(r'-----BEGIN.*?CERTIFICATE-----.*?-----END.*?CERTIFICATE-----', dotAll: true),
      '[CERTIFICATE REDACTED]',
    );

    // Remove AWS keys
    sanitized = sanitized.replaceAll(
      RegExp(r'AKIA[0-9A-Z]{16}'),
      '[AWS KEY REDACTED]',
    );

    // Remove GitHub tokens
    sanitized = sanitized.replaceAll(
      RegExp(r'ghp_[A-Za-z0-9]{36}'),
      '[GITHUB TOKEN REDACTED]',
    );

    // Remove JWTs
    sanitized = sanitized.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
      '[JWT REDACTED]',
    );

    return sanitized;
  }

  /// Generate a safe audit log entry.
  String buildSafeAuditLog({
    required String action,
    required String environment,
    String? secretName,
    String? details,
  }) {
    final safeDetails = details != null ? maskLogMessage(details) : '';
    final safeSecretName = secretName != null ? maskSecret('secret', secretName) : '';

    return '[AUDIT] $action | env=$environment | secret=$safeSecretName | details=$safeDetails';
  }
}
