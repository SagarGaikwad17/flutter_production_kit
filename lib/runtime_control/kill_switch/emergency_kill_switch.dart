import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/kill_switch.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';
import 'package:flutter_production_kit/runtime_control/domain/repositories/runtime_control_repository.dart';

/// Emergency kill switch — instant feature/route/API disable.
///
/// Design rationale:
/// - Kill switches are evaluated BEFORE all other checks.
/// - A kill switch cannot be overridden by local overrides or targeting rules.
/// - Kill switches are scoped: feature, route, apiAction, or global.
/// - Kill switch state is persisted — survives app restarts.
/// - [globalActive] blocks ALL features when activated (nuclear option).
///
/// Usage:
/// ```dart
/// // Activate kill switch for a broken feature:
/// await killSwitch.activate(
///   key: 'payment_module',
///   scope: KillSwitchScope.feature,
///   target: 'payment_v2',
///   reason: 'Payment processing errors in production',
///   activatedBy: 'ops_team',
/// );
///
/// // Check if a feature is blocked:
/// final isActive = await killSwitch.isActive(featureKey: 'payment_v2');
/// ```
class EmergencyKillSwitch {
  EmergencyKillSwitch({
    required RuntimeControlRepository repository,
  }) : _repository = repository;

  static const String _tag = 'EmergencyKillSwitch';

  final RuntimeControlRepository _repository;

  bool _globalActive = false;
  final Map<String, KillSwitch> _switches = {};

  /// Check if a kill switch is active for the given context.
  Future<KillSwitchStatus> isActive({
    String? featureKey,
    String? route,
    String? apiAction,
  }) async {
    // Global kill switch — blocks everything.
    if (_globalActive) {
      return KillSwitchStatus(
        active: true,
        key: 'global',
        scope: KillSwitchScope.global,
        reason: 'Global kill switch activated.',
      );
    }

    // Check specific kill switches.
    for (final switchEntry in _switches.values) {
      if (switchEntry.matches(
        featureKey: featureKey,
        route: route,
        apiAction: apiAction,
      )) {
        AppLogger.warning(
          _tag,
          'Kill switch active: ${switchEntry.key} '
          '(${switchEntry.scope.name}, target: ${switchEntry.target})',
        );
        return KillSwitchStatus(
          active: true,
          key: switchEntry.key,
          scope: switchEntry.scope,
          target: switchEntry.target,
          reason: switchEntry.reason,
          activatedBy: switchEntry.activatedBy,
        );
      }
    }

    // Check repository for remote kill switches.
    final remoteSwitches = await _repository.getActiveKillSwitches();
    for (final switchEntry in remoteSwitches) {
      if (switchEntry.matches(
        featureKey: featureKey,
        route: route,
        apiAction: apiAction,
      )) {
        return KillSwitchStatus(
          active: true,
          key: switchEntry.key,
          scope: switchEntry.scope,
          target: switchEntry.target,
          reason: switchEntry.reason,
          activatedBy: switchEntry.activatedBy,
        );
      }
    }

    return KillSwitchStatus(active: false, key: '');
  }

  /// Activate a kill switch.
  Future<void> activate({
    required String key,
    required KillSwitchScope scope,
    String? target,
    String? reason,
    String? activatedBy,
    DateTime? expiresAt,
  }) async {
    final killSwitch = KillSwitch(
      key: key,
      active: true,
      scope: scope,
      target: target,
      reason: reason,
      activatedAt: DateTime.now(),
      activatedBy: activatedBy,
      expiresAt: expiresAt,
    );

    _switches[key] = killSwitch;
    await _repository.updateKillSwitch(killSwitch);

    AppLogger.warning(
      _tag,
      'Kill switch ACTIVATED: $key (${scope.name}, target: $target) '
      'by $activatedBy — reason: $reason',
    );
  }

  /// Deactivate a kill switch.
  Future<void> deactivate(String key) async {
    final existing = _switches[key];
    if (existing == null) return;

    _switches[key] = existing.deactivate();

    AppLogger.info(_tag, 'Kill switch deactivated: $key');
  }

  /// Activate the GLOBAL kill switch — blocks ALL features.
  /// Use with extreme caution — this is the nuclear option.
  Future<void> activateGlobal({
    String? reason,
    String? activatedBy,
  }) async {
    _globalActive = true;

    AppLogger.warning(
      _tag,
      'GLOBAL KILL SWITCH ACTIVATED — all features blocked. '
      'Reason: $reason, By: $activatedBy',
    );
  }

  /// Deactivate the global kill switch.
  Future<void> deactivateGlobal() async {
    _globalActive = false;
    AppLogger.info(_tag, 'Global kill switch deactivated.');
  }

  /// Initialize kill switches from the active config.
  Future<void> initializeFromConfig(RuntimeConfig config) async {
    for (final entry in config.killSwitches.entries) {
      final killConfig = entry.value;
      final killSwitch = KillSwitch(
        key: killConfig.key,
        active: killConfig.active,
        scope: killConfig.scope,
        target: killConfig.target,
        reason: killConfig.reason,
        activatedAt: killConfig.activatedAt,
        activatedBy: killConfig.activatedBy,
      );
      _switches[killConfig.key] = killSwitch;
    }

    AppLogger.info(
      _tag,
      'Kill switches initialized: ${_switches.length} active switches.',
    );
  }

  /// Get all active kill switches.
  List<KillSwitch> get activeSwitches =>
      _switches.values.where((s) => s.isActive).toList();

  /// Get the global kill switch state.
  bool get isGlobalActive => _globalActive;
}

/// Kill switch status — returned by isActive().
class KillSwitchStatus {
  const KillSwitchStatus({
    required this.active,
    required this.key,
    this.scope,
    this.target,
    this.reason,
    this.activatedBy,
  });

  final bool active;
  final String key;
  final KillSwitchScope? scope;
  final String? target;
  final String? reason;
  final String? activatedBy;
}
