import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';

/// Offline action policy — defines which actions are allowed when offline.
///
/// Design rationale:
/// - Not all actions are safe offline. Payments should be blocked.
/// - Actions are classified by [OfflineActionSafety].
/// - Per-resource-type rules override global defaults.
/// - This policy is consulted BEFORE enqueuing an offline operation.
/// - If an action is blocked, the user gets immediate feedback.
///
/// Safety levels:
/// - [allowed] — safe to perform offline and sync later (draft notes, reads).
/// - [allowedWithWarning] — allowed but user should be warned (record updates).
/// - [blocked] — never allowed offline (payments, deletions, admin actions).
/// - [allowedCritical] — allowed offline, sync immediately when online (emergency).
class OfflineActionPolicy {
  const OfflineActionPolicy({
    this.globalDefault = OfflineActionSafety.allowedWithWarning,
    Map<String, Map<SyncAction, OfflineActionSafety>>? resourceRules,
  }) : _resourceRules = resourceRules ?? const {};

  final OfflineActionSafety globalDefault;
  final Map<String, Map<SyncAction, OfflineActionSafety>> _resourceRules;

  /// Check if an action is allowed when offline.
  OfflineActionSafety check({
    required String resourceType,
    required SyncAction action,
  }) {
    final resourceRule = _resourceRules[resourceType];
    if (resourceRule != null) {
      return resourceRule[action] ?? globalDefault;
    }
    return globalDefault;
  }

  /// Check if an action is BLOCKED when offline.
  bool isBlocked({
    required String resourceType,
    required SyncAction action,
  }) {
    return check(resourceType: resourceType, action: action) ==
        OfflineActionSafety.blocked;
  }

  /// Get all blocked actions for a resource type.
  List<SyncAction> getBlockedActions(String resourceType) {
    return SyncAction.values
        .where((action) => isBlocked(resourceType: resourceType, action: action))
        .toList();
  }

  /// Preset for healthcare/clinic apps — strict offline controls.
  static const OfflineActionPolicy healthcare = OfflineActionPolicy(
    globalDefault: OfflineActionSafety.allowedWithWarning,
    resourceRules: {
      'prescription': {
        SyncAction.create: OfflineActionSafety.blocked,
        SyncAction.delete: OfflineActionSafety.blocked,
        SyncAction.update: OfflineActionSafety.allowedWithWarning,
      },
      'payment': {
        SyncAction.create: OfflineActionSafety.blocked,
        SyncAction.delete: OfflineActionSafety.blocked,
        SyncAction.update: OfflineActionSafety.blocked,
      },
      'appointment': {
        SyncAction.create: OfflineActionSafety.allowed,
        SyncAction.update: OfflineActionSafety.allowed,
        SyncAction.delete: OfflineActionSafety.blocked,
      },
      'patient_note': {
        SyncAction.create: OfflineActionSafety.allowed,
        SyncAction.update: OfflineActionSafety.allowed,
        SyncAction.delete: OfflineActionSafety.allowedWithWarning,
      },
    },
  );

  /// Preset for delivery/field apps — moderate offline controls.
  static const OfflineActionPolicy delivery = OfflineActionPolicy(
    globalDefault: OfflineActionSafety.allowed,
    resourceRules: {
      'delivery': {
        SyncAction.create: OfflineActionSafety.allowedCritical,
        SyncAction.update: OfflineActionSafety.allowed,
        SyncAction.delete: OfflineActionSafety.blocked,
      },
      'signature': {
        SyncAction.create: OfflineActionSafety.allowed,
        SyncAction.update: OfflineActionSafety.blocked,
      },
      'payment': {
        SyncAction.create: OfflineActionSafety.blocked,
        SyncAction.update: OfflineActionSafety.blocked,
      },
    },
  );

  /// Preset for CRM apps — lenient offline controls.
  static const OfflineActionPolicy crm = OfflineActionPolicy(
    globalDefault: OfflineActionSafety.allowed,
    resourceRules: {
      'deal': {
        SyncAction.create: OfflineActionSafety.allowed,
        SyncAction.update: OfflineActionSafety.allowed,
        SyncAction.delete: OfflineActionSafety.blocked,
      },
      'contact': {
        SyncAction.create: OfflineActionSafety.allowed,
        SyncAction.update: OfflineActionSafety.allowed,
        SyncAction.delete: OfflineActionSafety.allowedWithWarning,
      },
      'invoice': {
        SyncAction.create: OfflineActionSafety.blocked,
        SyncAction.update: OfflineActionSafety.blocked,
        SyncAction.delete: OfflineActionSafety.blocked,
      },
    },
  );
}

enum OfflineActionSafety {
  allowed,
  allowedWithWarning,
  allowedCritical,
  blocked,
}
