/// Runtime configuration — the complete set of remote config values.
///
/// Design rationale:
/// - Holds ALL runtime-controllable values: feature flags, kill switches,
///   config parameters, and rollout rules.
/// - [version] enables cache invalidation and rollback detection.
/// - [fetchedAt] enables stale config detection.
/// - [ttl] defines how long this config is valid before requiring refresh.
/// - [signature] enables tamper detection for security-sensitive configs.
/// - [environment] prevents cross-environment config leaks.
class RuntimeConfig {
  const RuntimeConfig({
    required this.version,
    required this.fetchedAt,
    this.ttl = const Duration(hours: 24),
    this.featureFlags = const {},
    this.killSwitches = const {},
    this.configValues = const {},
    this.rolloutRules = const {},
    this.signature,
    this.environment = 'production',
    this.metadata = const {},
  });

  final int version;
  final DateTime fetchedAt;
  final Duration ttl;
  final Map<String, FeatureFlagConfig> featureFlags;
  final Map<String, KillSwitchConfig> killSwitches;
  final Map<String, String> configValues;
  final Map<String, RolloutRuleConfig> rolloutRules;
  final String? signature;
  final String environment;
  final Map<String, String> metadata;

  bool get isExpired {
    return DateTime.now().isAfter(fetchedAt.add(ttl));
  }

  bool isValidForEnvironment(String currentEnvironment) {
    return environment == currentEnvironment;
  }

  RuntimeConfig copyWith({
    int? version,
    DateTime? fetchedAt,
    Duration? ttl,
    Map<String, FeatureFlagConfig>? featureFlags,
    Map<String, KillSwitchConfig>? killSwitches,
    Map<String, String>? configValues,
    Map<String, RolloutRuleConfig>? rolloutRules,
    String? signature,
    String? environment,
  }) {
    return RuntimeConfig(
      version: version ?? this.version,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      ttl: ttl ?? this.ttl,
      featureFlags: featureFlags ?? this.featureFlags,
      killSwitches: killSwitches ?? this.killSwitches,
      configValues: configValues ?? this.configValues,
      rolloutRules: rolloutRules ?? this.rolloutRules,
      signature: signature ?? this.signature,
      environment: environment ?? this.environment,
      metadata: metadata,
    );
  }

  static final RuntimeConfig empty = RuntimeConfig(
    version: 0,
    fetchedAt: DateTime(1970),
  );
}

/// Feature flag config — the remote representation of a feature flag.
class FeatureFlagConfig {
  const FeatureFlagConfig({
    required this.key,
    required this.enabled,
    this.rolloutPercentage = 100,
    this.targetingRules = const [],
    this.requiredEntitlements = const [],
    this.allowedTenants,
    this.blockedTenants,
    this.allowedWhiteLabels,
    this.blockedWhiteLabels,
    this.metadata = const {},
  });

  final String key;
  final bool enabled;
  final int rolloutPercentage;
  final List<String> targetingRules;
  final List<String> requiredEntitlements;
  final List<String>? allowedTenants;
  final List<String>? blockedTenants;
  final List<String>? allowedWhiteLabels;
  final List<String>? blockedWhiteLabels;
  final Map<String, String> metadata;
}

/// Kill switch config — the remote representation of a kill switch.
class KillSwitchConfig {
  const KillSwitchConfig({
    required this.key,
    required this.active,
    this.scope = KillSwitchScope.feature,
    this.target,
    this.reason,
    this.activatedAt,
    this.activatedBy,
  });

  final String key;
  final bool active;
  final KillSwitchScope scope;
  final String? target;
  final String? reason;
  final DateTime? activatedAt;
  final String? activatedBy;
}

/// Rollout rule config — the remote representation of a rollout rule.
class RolloutRuleConfig {
  const RolloutRuleConfig({
    required this.key,
    required this.percentage,
    this.salt = '',
    this.targetingRules = const [],
  });

  final String key;
  final int percentage;
  final String salt;
  final List<String> targetingRules;
}

/// Cached config entry — stores versioned config for fallback.
class CachedConfigEntry {
  const CachedConfigEntry({
    required this.config,
    required this.storedAt,
    this.isValid = true,
  });

  final RuntimeConfig config;
  final DateTime storedAt;
  final bool isValid;
}

enum KillSwitchScope {
  feature,
  route,
  apiAction,
  global,
}
