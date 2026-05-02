/// Deployment state — tracks a deployment across platforms and environments.
///
/// Design rationale:
/// - Immutable deployment record.
/// - Tracks per-platform status (Android, iOS, web).
/// - Tracks rollout state.
/// - Tracks approval state.
/// - Supports partial deployment tracking.
/// - Audit-safe — no sensitive data.
class DeploymentState {
  const DeploymentState({
    required this.id,
    required this.releaseId,
    required this.environment,
    required this.status,
    required this.createdAt,
    this.platformStates = const {},
    this.rolloutState,
    this.approvalState,
    this.deployedBy,
    this.completedAt,
    this.failureReason,
    this.rollbackTargetId,
  });

  final String id;
  final String releaseId;
  final String environment;
  final DeploymentStatus status;
  final DateTime createdAt;
  final Map<String, PlatformDeploymentState> platformStates;
  final String? rolloutState;
  final String? approvalState;
  final String? deployedBy;
  final DateTime? completedAt;
  final String? failureReason;
  final String? rollbackTargetId;

  bool get isComplete => status == DeploymentStatus.completed;
  bool get isFailed => status == DeploymentStatus.failed;
  bool get isRollingOut => status == DeploymentStatus.rollingOut;
  bool get isRolledBack => status == DeploymentStatus.rolledBack;

  bool get isPartiallyDeployed {
    if (platformStates.isEmpty) return false;
    final deployed = platformStates.values
        .where((s) => s.status == PlatformDeploymentStatus.deployed)
        .length;
    return deployed > 0 && deployed < platformStates.length;
  }

  DeploymentState addPlatformState(PlatformDeploymentState state) {
    return copyWith(
      platformStates: {...platformStates, state.platform: state},
    );
  }

  DeploymentState fail(String reason) {
    return copyWith(
      status: DeploymentStatus.failed,
      failureReason: reason,
      completedAt: DateTime.now(),
    );
  }

  DeploymentState complete() {
    return copyWith(
      status: DeploymentStatus.completed,
      completedAt: DateTime.now(),
    );
  }

  DeploymentState copyWith({
    DeploymentStatus? status,
    Map<String, PlatformDeploymentState>? platformStates,
    String? failureReason,
    DateTime? completedAt,
    String? rollbackTargetId,
  }) {
    return DeploymentState(
      id: id,
      releaseId: releaseId,
      environment: environment,
      status: status ?? this.status,
      createdAt: createdAt,
      platformStates: platformStates ?? this.platformStates,
      rolloutState: rolloutState,
      approvalState: approvalState,
      deployedBy: deployedBy,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      rollbackTargetId: rollbackTargetId ?? this.rollbackTargetId,
    );
  }
}

enum DeploymentStatus {
  pending,
  validating,
  signing,
  approved,
  rollingOut,
  completed,
  failed,
  rolledBack,
}

class PlatformDeploymentState {
  const PlatformDeploymentState({
    required this.platform,
    required this.status,
    required this.buildNumber,
    this.artifactUrl,
    this.checksum,
    this.failureReason,
    this.deployedAt,
  });

  final String platform;
  final PlatformDeploymentStatus status;
  final int buildNumber;
  final String? artifactUrl;
  final String? checksum;
  final String? failureReason;
  final DateTime? deployedAt;

  bool get isDeployed => status == PlatformDeploymentStatus.deployed;
  bool get isFailed => status == PlatformDeploymentStatus.failed;
}

enum PlatformDeploymentStatus {
  pending,
  building,
  built,
  signing,
  signed,
  deployed,
  failed,
}
