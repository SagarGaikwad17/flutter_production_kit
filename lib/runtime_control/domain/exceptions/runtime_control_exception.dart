/// Runtime control exception hierarchy.
///
/// Design rationale:
/// - Each exception type maps to a specific failure mode in the runtime control system.
/// - [RuntimeControlException] is the base for all runtime control errors.
/// - [ConfigFetchException] covers remote config fetch failures.
/// - [ConfigParseException] covers config parsing/deserialization failures.
/// - [ConfigValidationException] covers config that fails validation.
/// - [StaleConfigException] covers expired or stale config rejection.
/// - [KillSwitchActivationException] covers emergency kill switch activations.
/// - [TargetingEvaluationException] covers targeting rule evaluation failures.
/// - [RolloutAssignmentException] covers rollout assignment failures.
/// - [WhiteLabelIsolationException] covers cross-client config leak prevention.
/// - NO sensitive data in exception messages.
sealed class RuntimeControlException implements Exception {
  const RuntimeControlException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'RuntimeControlException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Remote config fetch failed.
final class ConfigFetchException extends RuntimeControlException {
  const ConfigFetchException({
    required super.message,
    super.cause,
    this.httpStatusCode,
    this.isRetryable = true,
  });

  final int? httpStatusCode;
  final bool isRetryable;
}

/// Config fetch timed out.
final class ConfigFetchTimeoutException extends ConfigFetchException {
  const ConfigFetchTimeoutException({
    required super.message,
    required this.timeout,
  });

  final Duration timeout;
}

/// Config parsing failed — malformed response.
final class ConfigParseException extends RuntimeControlException {
  const ConfigParseException({
    required super.message,
    super.cause,
    this.rawResponse,
  });

  final String? rawResponse;
}

/// Config validation failed — missing required fields or invalid values.
final class ConfigValidationException extends RuntimeControlException {
  const ConfigValidationException({
    required super.message,
    this.fieldErrors = const [],
  });

  final List<String> fieldErrors;
}

/// Config is stale — exceeds maximum age.
final class StaleConfigException extends RuntimeControlException {
  const StaleConfigException({
    required super.message,
    required this.configAge,
    required this.maxAge,
  });

  final Duration configAge;
  final Duration maxAge;
}

/// No cached config available for fallback.
final class NoCachedConfigException extends RuntimeControlException {
  const NoCachedConfigException({required super.message});
}

/// Environment mismatch — config is for a different environment.
final class EnvironmentMismatchException extends RuntimeControlException {
  const EnvironmentMismatchException({
    required super.message,
    required this.configEnvironment,
    required this.currentEnvironment,
  });

  final String configEnvironment;
  final String currentEnvironment;
}

/// Kill switch activated — feature/route/API is blocked.
final class KillSwitchActivationException extends RuntimeControlException {
  const KillSwitchActivationException({
    required super.message,
    this.killSwitchKey,
    this.scope,
    this.target,
  });

  final String? killSwitchKey;
  final String? scope;
  final String? target;
}

/// Targeting rule evaluation failed.
final class TargetingEvaluationException extends RuntimeControlException {
  const TargetingEvaluationException({
    required super.message,
    super.cause,
    this.targetingRuleId,
  });

  final String? targetingRuleId;
}

/// Rollout assignment failed.
final class RolloutAssignmentException extends RuntimeControlException {
  const RolloutAssignmentException({
    required super.message,
    this.featureKey,
    this.rolloutPercentage,
  });

  final String? featureKey;
  final int? rolloutPercentage;
}

/// White-label isolation violation — config leaked across clients.
final class WhiteLabelIsolationException extends RuntimeControlException {
  const WhiteLabelIsolationException({
    required super.message,
    this.requestedClient,
    this.configClient,
  });

  final String? requestedClient;
  final String? configClient;
}

/// Local override rejected — not allowed in production.
final class LocalOverrideRejectedException extends RuntimeControlException {
  const LocalOverrideRejectedException({
    required super.message,
    required this.featureKey,
  });

  final String featureKey;
}
