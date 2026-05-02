import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/feature_evaluation_result.dart';

/// Runtime control observer — observability layer for feature flags and runtime control.
///
/// Design rationale:
/// - Provides hooks for monitoring, logging, and alerting.
/// - All observability events flow through this single point.
/// - Listeners can be registered for UI updates, analytics, and alerting.
/// - NO sensitive data is emitted — only safe metadata.
/// - Structured events enable dashboards and alerting systems.
///
/// Observable events:
/// - Feature flag evaluations (enabled/disabled with reason)
/// - Kill switch activations and evaluations
/// - Config sync success/failure
/// - Stale config rejections
/// - Local override usage
/// - Rollout assignments
/// - White-label isolation events
/// - Entitlement downgrade events
class RuntimeControlObserver {
  RuntimeControlObserver({
    this.enableDetailedLogging = true,
  });

  static const String _tag = 'RuntimeControlObserver';

  final bool enableDetailedLogging;

  final List<RuntimeControlEventListener> _listeners = [];

  // ── Feature Evaluations ────────────────────────────────────────────────────

  void onFeatureEvaluated({
    required String featureKey,
    required FeatureEvaluationResult result,
    String? userId,
  }) {
    final safeUserId = userId != null ? _maskUserId(userId) : 'anonymous';
    _log('Feature "$featureKey" evaluated for $safeUserId: ${result.runtimeType}');
    _emit(FeatureEvaluatedEvent(featureKey, result, safeUserId));
  }

  void onFlagNotFound(String featureKey) {
    _log('Feature flag not found: $featureKey');
    _emit(FlagNotFoundEvent(featureKey));
  }

  void onEvaluationError(String featureKey, String error) {
    _log('Feature evaluation error: $featureKey — $error');
    _emit(FeatureEvaluationErrorEvent(featureKey, error));
  }

  // ── Kill Switch ────────────────────────────────────────────────────────────

  void onKillSwitchEvaluated(String featureKey, bool isActive) {
    if (isActive) {
      _log('Kill switch ACTIVE for feature: $featureKey');
    }
    _emit(KillSwitchEvaluatedEvent(featureKey, isActive));
  }

  void onKillSwitchActivated(String key, String? reason) {
    _log('Kill switch ACTIVATED: $key — $reason');
    _emit(KillSwitchActivatedEvent(key, reason));
  }

  void onKillSwitchDeactivated(String key) {
    _log('Kill switch deactivated: $key');
    _emit(KillSwitchDeactivatedEvent(key));
  }

  // ── Config Sync ────────────────────────────────────────────────────────────

  void onConfigLoaded(int version, String environment) {
    _log('Config loaded: version $version, env: $environment');
    _emit(ConfigLoadedEvent(version, environment));
  }

  void onConfigSyncSuccess(int version) {
    _log('Config sync success: version $version');
    _emit(ConfigSyncSuccessEvent(version));
  }

  void onConfigSyncFailure(String error) {
    _log('Config sync failure: $error');
    _emit(ConfigSyncFailureEvent(error));
  }

  void onConfigSyncRejected(String reason) {
    _log('Config sync rejected: $reason');
    _emit(ConfigSyncRejectedEvent(reason));
  }

  // ── Stale Config ───────────────────────────────────────────────────────────

  void onStaleConfigRejected(String featureKey) {
    _log('Stale config rejected for feature: $featureKey');
    _emit(StaleConfigRejectedEvent(featureKey));
  }

  // ── Local Override ─────────────────────────────────────────────────────────

  void onLocalOverrideUsed(String featureKey, bool enabled) {
    _log('Local override used: $featureKey = $enabled');
    _emit(LocalOverrideUsedEvent(featureKey, enabled));
  }

  void onLocalOverrideRejected(String featureKey, String reason) {
    _log('Local override rejected: $featureKey — $reason');
    _emit(LocalOverrideRejectedEvent(featureKey, reason));
  }

  // ── Rollout ────────────────────────────────────────────────────────────────

  void onRolloutAssignment({
    required String featureKey,
    required bool isInGroup,
    required int percentage,
    String? userId,
  }) {
    final safeUserId = userId != null ? _maskUserId(userId) : 'anonymous';
    _log('Rollout: $featureKey, $safeUserId → ${isInGroup ? "IN" : "OUT"} ($percentage%)');
    _emit(RolloutAssignmentEvent(featureKey, isInGroup, percentage, safeUserId));
  }

  // ── Entitlement ────────────────────────────────────────────────────────────

  void onEntitlementDowngrade({
    required String featureKey,
    required String requiredEntitlement,
    String? userId,
  }) {
    _log('Entitlement downgrade: $featureKey — missing $requiredEntitlement');
    _emit(EntitlementDowngradeEvent(featureKey, requiredEntitlement, userId));
  }

  // ── White-Label ────────────────────────────────────────────────────────────

  void onWhiteLabelIsolation({
    required String featureKey,
    required String client,
  }) {
    _log('White-label isolation: $featureKey blocked for client $client');
    _emit(WhiteLabelIsolationEvent(featureKey, client));
  }

  // ── Listener Management ────────────────────────────────────────────────────

  void addListener(RuntimeControlEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(RuntimeControlEventListener listener) {
    _listeners.remove(listener);
  }

  void clearListeners() {
    _listeners.clear();
  }

  void _emit(RuntimeControlEvent event) {
    for (final listener in _listeners) {
      listener.onEvent(event);
    }
  }

  void _log(String message) {
    if (enableDetailedLogging) {
      AppLogger.debug(_tag, message);
    }
  }

  String _maskUserId(String userId) {
    if (userId.length <= 4) return '****';
    return '${userId.substring(0, 2)}****${userId.substring(userId.length - 2)}';
  }
}

/// Abstract listener for runtime control events.
abstract class RuntimeControlEventListener {
  void onEvent(RuntimeControlEvent event);
}

/// Base class for all runtime control events.
sealed class RuntimeControlEvent {
  const RuntimeControlEvent();
}

final class FeatureEvaluatedEvent extends RuntimeControlEvent {
  const FeatureEvaluatedEvent(this.featureKey, this.result, this.userId);
  final String featureKey;
  final FeatureEvaluationResult result;
  final String userId;
}

final class FlagNotFoundEvent extends RuntimeControlEvent {
  const FlagNotFoundEvent(this.featureKey);
  final String featureKey;
}

final class FeatureEvaluationErrorEvent extends RuntimeControlEvent {
  const FeatureEvaluationErrorEvent(this.featureKey, this.error);
  final String featureKey;
  final String error;
}

final class KillSwitchEvaluatedEvent extends RuntimeControlEvent {
  const KillSwitchEvaluatedEvent(this.featureKey, this.isActive);
  final String featureKey;
  final bool isActive;
}

final class KillSwitchActivatedEvent extends RuntimeControlEvent {
  const KillSwitchActivatedEvent(this.key, this.reason);
  final String key;
  final String? reason;
}

final class KillSwitchDeactivatedEvent extends RuntimeControlEvent {
  const KillSwitchDeactivatedEvent(this.key);
  final String key;
}

final class ConfigLoadedEvent extends RuntimeControlEvent {
  const ConfigLoadedEvent(this.version, this.environment);
  final int version;
  final String environment;
}

final class ConfigSyncSuccessEvent extends RuntimeControlEvent {
  const ConfigSyncSuccessEvent(this.version);
  final int version;
}

final class ConfigSyncFailureEvent extends RuntimeControlEvent {
  const ConfigSyncFailureEvent(this.error);
  final String error;
}

final class ConfigSyncRejectedEvent extends RuntimeControlEvent {
  const ConfigSyncRejectedEvent(this.reason);
  final String reason;
}

final class StaleConfigRejectedEvent extends RuntimeControlEvent {
  const StaleConfigRejectedEvent(this.featureKey);
  final String featureKey;
}

final class LocalOverrideUsedEvent extends RuntimeControlEvent {
  const LocalOverrideUsedEvent(this.featureKey, this.enabled);
  final String featureKey;
  final bool enabled;
}

final class LocalOverrideRejectedEvent extends RuntimeControlEvent {
  const LocalOverrideRejectedEvent(this.featureKey, this.reason);
  final String featureKey;
  final String reason;
}

final class RolloutAssignmentEvent extends RuntimeControlEvent {
  const RolloutAssignmentEvent(this.featureKey, this.isInGroup, this.percentage, this.userId);
  final String featureKey;
  final bool isInGroup;
  final int percentage;
  final String userId;
}

final class EntitlementDowngradeEvent extends RuntimeControlEvent {
  const EntitlementDowngradeEvent(this.featureKey, this.requiredEntitlement, this.userId);
  final String featureKey;
  final String requiredEntitlement;
  final String? userId;
}

final class WhiteLabelIsolationEvent extends RuntimeControlEvent {
  const WhiteLabelIsolationEvent(this.featureKey, this.client);
  final String featureKey;
  final String client;
}
