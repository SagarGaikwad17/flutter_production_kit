/// Rollout state — represents a staged rollout's configuration and progress.
///
/// Design rationale:
/// - Tracks rollout percentage, regions, and tenant targeting.
/// - Health gates determine if rollout should continue, pause, or rollback.
/// - Region-based rollout allows geographic staging.
/// - Tenant-based rollout allows enterprise customer staging.
/// - Emergency rollback bypasses normal gates for critical fixes.
///
/// Health gate triggers:
/// - Crash rate spike → pause.
/// - API error rate spike → pause.
/// - User complaint spike → pause.
/// - Billing failure spike → pause.
/// - Tenant isolation violation → immediate rollback.
class RolloutState {
  const RolloutState({
    required this.releaseId,
    required this.currentPercentage,
    required this.targetPercentage,
    required this.status,
    required this.startedAt,
    this.id = '',
    this.regions = const [],
    this.tenantIds = const [],
    this.healthGates = const {},
    this.pauseReason,
    this.pausedAt,
    this.lastUpdated,
    this.checkpoints = const [],
  });

  final String id;
  final String releaseId;
  final int currentPercentage;
  final int targetPercentage;
  final RolloutStatus status;
  final List<String> regions;
  final List<String> tenantIds;
  final Map<String, RolloutHealthGate> healthGates;
  final DateTime startedAt;
  final String? pauseReason;
  final DateTime? pausedAt;
  final DateTime? lastUpdated;
  final List<RolloutCheckpoint> checkpoints;

  bool get isComplete => currentPercentage >= targetPercentage;
  bool get isPaused => status == RolloutStatus.paused;
  bool get isRollingOut => status == RolloutStatus.active;
  bool get isEmergency => status == RolloutStatus.emergency;

  bool shouldPause() {
    for (final gate in healthGates.values) {
      if (gate.isTriggered) return true;
    }
    return false;
  }

  bool shouldRollback() {
    for (final gate in healthGates.values) {
      if (gate.shouldRollback) return true;
    }
    return false;
  }

  RolloutState incrementPercentage(int newPercentage) {
    return copyWith(
      currentPercentage: newPercentage,
      status: newPercentage >= targetPercentage
          ? RolloutStatus.completed
          : RolloutStatus.active,
      lastUpdated: DateTime.now(),
      checkpoints: [
        ...checkpoints,
        RolloutCheckpoint(
          percentage: newPercentage,
          timestamp: DateTime.now(),
          status: 'incremented',
        ),
      ],
    );
  }

  RolloutState pause(String reason) {
    return copyWith(
      status: RolloutStatus.paused,
      pauseReason: reason,
      pausedAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
  }

  RolloutState resume() {
    return copyWith(
      status: RolloutStatus.active,
      pauseReason: null,
      pausedAt: null,
      lastUpdated: DateTime.now(),
    );
  }

  RolloutState copyWith({
    int? currentPercentage,
    int? targetPercentage,
    RolloutStatus? status,
    String? pauseReason,
    DateTime? pausedAt,
    DateTime? lastUpdated,
    List<RolloutCheckpoint>? checkpoints,
    Map<String, RolloutHealthGate>? healthGates,
  }) {
    return RolloutState(
      id: id,
      releaseId: releaseId,
      currentPercentage: currentPercentage ?? this.currentPercentage,
      targetPercentage: targetPercentage ?? this.targetPercentage,
      status: status ?? this.status,
      startedAt: startedAt,
      regions: regions,
      tenantIds: tenantIds,
      healthGates: healthGates ?? this.healthGates,
      pauseReason: pauseReason ?? this.pauseReason,
      pausedAt: pausedAt ?? this.pausedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }
}

enum RolloutStatus {
  active,
  paused,
  completed,
  rolledBack,
  emergency,
}

class RolloutHealthGate {
  const RolloutHealthGate({
    required this.name,
    required this.threshold,
    required this.metric,
    required this.rollbackThreshold,
    this.isTriggered = false,
    this.shouldRollback = false,
    this.currentValue,
  });

  final String name;
  final double threshold;
  final String metric;
  final double rollbackThreshold;
  final bool isTriggered;
  final bool shouldRollback;
  final double? currentValue;

  RolloutHealthGate evaluate(double value) {
    final triggered = value > threshold;
    final rollback = value > rollbackThreshold;
    return RolloutHealthGate(
      name: name,
      threshold: threshold,
      metric: metric,
      rollbackThreshold: rollbackThreshold,
      isTriggered: triggered,
      shouldRollback: rollback,
      currentValue: value,
    );
  }
}

class RolloutCheckpoint {
  const RolloutCheckpoint({
    required this.percentage,
    required this.timestamp,
    required this.status,
    this.reason,
  });

  final int percentage;
  final DateTime timestamp;
  final String status;
  final String? reason;
}
