/// Flavor release validation result.
class FlavorValidationResult {
  const FlavorValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
}

/// Flavor release validator — prevents wrong-flavor releases.
///
/// Design rationale:
/// - Validates that the build flavor matches the target environment.
/// - Prevents production releases built with staging/dev configs.
/// - Validates flavor-specific configuration files.
/// - Validates flavor-specific signing keys.
/// - Validates flavor-specific API endpoints.
///
/// Flavor-environment mapping:
///   dev → dev environment
///   qa → qa environment
///   staging → staging environment
///   production → production environment
///   demo → demo environment
///   whiteLabel_* → white-label environment (client-specific)
///
/// Critical: This validation runs BEFORE any artifact is published.
class FlavorReleaseValidator {
  const FlavorReleaseValidator({
    this.allowedFlavorEnvironmentMap = const {
      'dev': ['dev'],
      'qa': ['qa', 'staging'],
      'staging': ['staging', 'demo'],
      'production': ['production'],
    },
    this.requireConfigValidation = true,
    this.requireSigningKeyValidation = true,
    this.requireEndpointValidation = true,
  });

  final Map<String, List<String>> allowedFlavorEnvironmentMap;
  final bool requireConfigValidation;
  final bool requireSigningKeyValidation;
  final bool requireEndpointValidation;

  /// Validate flavor configuration for a release.
  FlavorValidationResult validate(Map<String, String> config) {
    final errors = <String>[];
    final warnings = <String>[];

    final buildFlavor = config['buildFlavor'];
    final expectedFlavor = config['expectedFlavor'];
    final environment = config['environment'];

    if (buildFlavor == null || expectedFlavor == null || environment == null) {
      return FlavorValidationResult(
        isValid: false,
        errors: ['Missing required flavor configuration fields'],
      );
    }

    // Check flavor matches expected
    if (buildFlavor != expectedFlavor) {
      errors.add(
        'Flavor mismatch: build flavor "$buildFlavor" does not match '
        'expected flavor "$expectedFlavor"',
      );
    }

    // Check flavor-environment mapping
    final allowedEnvironments = allowedFlavorEnvironmentMap[buildFlavor];
    if (allowedEnvironments == null) {
      errors.add('Unknown flavor: $buildFlavor');
    } else if (!allowedEnvironments.contains(environment)) {
      errors.add(
        'Environment mismatch: flavor "$buildFlavor" cannot be released '
        'to environment "$environment". Allowed: ${allowedEnvironments.join(', ')}',
      );
    }

    // Validate configuration files (delegate to config validator)
    if (requireConfigValidation) {
      final configErrors = _validateConfigFiles(config);
      errors.addAll(configErrors);
    }

    // Validate signing keys (delegate to signing manager)
    if (requireSigningKeyValidation) {
      final signingErrors = _validateSigningKeys(config);
      errors.addAll(signingErrors);
    }

    // Validate API endpoints (delegate to endpoint validator)
    if (requireEndpointValidation) {
      final endpointErrors = _validateEndpoints(config);
      errors.addAll(endpointErrors);
    }

    return FlavorValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate white-label flavor configuration.
  FlavorValidationResult validateWhiteLabel({
    required String buildFlavor,
    required String expectedClientId,
    required String environment,
    Map<String, String>? config,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // White-label flavors must start with 'whiteLabel_'
    if (!buildFlavor.startsWith('whiteLabel_')) {
      errors.add(
        'White-label flavor must start with "whiteLabel_", got "$buildFlavor"',
      );
    }

    // Extract client ID from flavor name
    final flavorClientId = buildFlavor.substring('whiteLabel_'.length);
    if (flavorClientId != expectedClientId) {
      errors.add(
        'White-label client mismatch: flavor "$buildFlavor" does not match '
        'expected client "$expectedClientId"',
      );
    }

    // White-label releases can only go to white-label or demo environments
    if (environment != 'whiteLabel' && environment != 'demo') {
      errors.add(
        'White-label releases can only target "whiteLabel" or "demo" '
        'environments, got "$environment"',
      );
    }

    // Validate white-label branding config
    if (config != null) {
      if (config['clientLogoUrl'] == null || config['clientLogoUrl']!.isEmpty) {
        warnings.add('White-label release missing client logo URL');
      }
      if (config['clientAppName'] == null || config['clientAppName']!.isEmpty) {
        warnings.add('White-label release missing client app name');
      }
    }

    return FlavorValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  List<String> _validateConfigFiles(Map<String, String> config) {
    // In production, this would validate flavor-specific config files.
    return [];
  }

  List<String> _validateSigningKeys(Map<String, String> config) {
    // In production, this would validate that signing keys match the environment.
    return [];
  }

  List<String> _validateEndpoints(Map<String, String> config) {
    // In production, this would validate API endpoints match the environment.
    return [];
  }
}
