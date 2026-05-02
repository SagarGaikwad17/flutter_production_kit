import 'package:flutter_production_kit/runtime_control/domain/entities/runtime_config.dart';

/// Emergency kill switch — instant feature/route/API disable.
///
/// Design rationale:
/// - Kill switches are evaluated BEFORE all other checks.
/// - A kill switch cannot be overridden by local overrides or targeting rules.
/// - Kill switches are scoped: feature, route, apiAction, or global.
/// - [reason] documents why the kill switch was activated (audit trail).
/// - [activatedBy] tracks who activated it.
/// - [expiresAt] supports auto-deactivation after a time window.
/// - Kill switch state is persisted and survives app restarts.
class KillSwitch {
  const KillSwitch({
    required this.key,
    required this.active,
    required this.scope,
    this.target,
    this.reason,
    this.activatedAt,
    this.activatedBy,
    this.expiresAt,
  });

  final String key;
  final bool active;
  final KillSwitchScope scope;
  final String? target;
  final String? reason;
  final DateTime? activatedAt;
  final String? activatedBy;
  final DateTime? expiresAt;

  bool get isExpired {
    final expires = expiresAt;
    if (expires == null) return false;
    return DateTime.now().isAfter(expires);
  }

  bool get isActive => active && !isExpired;

  bool matches({String? featureKey, String? route, String? apiAction}) {
    if (!isActive) return false;

    return switch (scope) {
      KillSwitchScope.global => true,
      KillSwitchScope.feature => target == featureKey,
      KillSwitchScope.route => target == route,
      KillSwitchScope.apiAction => target == apiAction,
    };
  }

  KillSwitch deactivate() {
    return KillSwitch(
      key: key,
      active: false,
      scope: scope,
      target: target,
      reason: reason,
      activatedAt: activatedAt,
      activatedBy: activatedBy,
      expiresAt: expiresAt,
    );
  }
}
