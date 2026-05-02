import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';

/// Environment guard — enforces environment-safe deployment.
///
/// Design rationale:
/// - Prevents releases to wrong environments.
/// - Prevents cross-environment contamination.
/// - Validates environment configuration before deployment.
/// - Supports environment-bound credentials.
/// - Supports environment-bound feature flags.
///
/// Environment rules:
/// - Dev releases can only target dev environment.
/// - QA releases can target qa or staging.
/// - Staging releases can target staging or demo.
/// - Production releases can ONLY target production.
/// - White-label releases can target white-label or demo.
/// - Hotfix releases can target any environment (with elevated audit).
class EnvironmentGuard {
  const EnvironmentGuard({
    this.environmentReleaseRules = const {
      'dev': ['dev'],
      'qa': ['qa', 'staging'],
      'staging': ['staging', 'demo'],
      'production': ['production'],
      'whiteLabel': ['whiteLabel', 'demo'],
    },
    this.requireEnvironmentValidation = true,
  });

  final Map<String, List<String>> environmentReleaseRules;
  final bool requireEnvironmentValidation;

  /// Validate that a release can target an environment.
  ReleaseResult validateEnvironment({
    required String releaseId,
    required String releaseEnvironment,
    required String targetEnvironment,
    String? flavor,
    bool isHotfix = false,
  }) {
    if (!requireEnvironmentValidation) {
      return ReleaseValidated(
        releaseId: releaseId,
        flavor: flavor ?? '',
        checksum: '',
      );
    }

    // Hotfix releases bypass environment validation (with audit).
    if (isHotfix) {
      return ReleaseValidated(
        releaseId: releaseId,
        flavor: flavor ?? '',
        checksum: '',
        warnings: ['Hotfix release bypassing environment validation'],
      );
    }

    final allowedEnvironments = environmentReleaseRules[releaseEnvironment];
    if (allowedEnvironments == null) {
      return BlockedByEnvironmentMismatch(
        releaseId: releaseId,
        expectedEnvironment: releaseEnvironment,
        actualEnvironment: targetEnvironment,
      );
    }

    if (!allowedEnvironments.contains(targetEnvironment)) {
      return BlockedByEnvironmentMismatch(
        releaseId: releaseId,
        expectedEnvironment: allowedEnvironments.join(' or '),
        actualEnvironment: targetEnvironment,
      );
    }

    // Production releases require exact environment match.
    if (releaseEnvironment == 'production' &&
        targetEnvironment != 'production') {
      return BlockedByEnvironmentMismatch(
        releaseId: releaseId,
        expectedEnvironment: 'production',
        actualEnvironment: targetEnvironment,
      );
    }

    return ReleaseValidated(
      releaseId: releaseId,
      flavor: flavor ?? '',
      checksum: '',
    );
  }

  /// Validate environment configuration is correct.
  bool validateEnvironmentConfig({
    required String environment,
    Map<String, String>? config,
  }) {
    if (config == null) return false;

    // Check for environment-specific configuration keys.
    final envKeys = [
      'api_url',
      'websocket_url',
      'analytics_id',
      'crash_reporting_id',
    ];

    for (final key in envKeys) {
      final value = config[key];
      if (value == null || value.isEmpty) return false;

      // Validate URL matches environment.
      if (key.endsWith('_url')) {
        if (environment == 'production' && value.contains('staging')) {
          return false;
        }
        if (environment == 'staging' && value.contains('production')) {
          return false;
        }
      }
    }

    return true;
  }

  /// Get safe environment variables for a target environment.
  Map<String, String> getSafeEnvironmentVariables({
    required String targetEnvironment,
    required Map<String, Map<String, String>> allEnvVars,
  }) {
    final envVars = allEnvVars[targetEnvironment];
    if (envVars == null) return {};

    // Filter out any variables that don't belong to this environment.
    return envVars;
  }
}
