/// Release state — represents a release artifact and its lifecycle stage.
///
/// Design rationale:
/// - Immutable state — releases never mutate, only transition.
/// - Flavor-bound — each release is tied to a specific flavor.
/// - Platform-scoped — Android and iOS releases tracked separately.
/// - Rollout-aware — tracks rollout percentage and health.
/// - Approval-gated — requires explicit approvals before promotion.
///
/// State machine:
///   drafted → validated → signed → approved → staged → rolled_out → completed
///   Any state → failed (with recovery path)
///   rolled_out → rollback_initiated → rolled_back → drafted (for retry)
///   staged → paused → resumed → rolled_out
class ReleaseState {
  const ReleaseState({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.flavor,
    required this.platform,
    required this.environment,
    required this.status,
    required this.createdAt,
    this.rolloutPercentage = 0,
    this.rolloutRegion,
    this.tenantId,
    this.isWhiteLabel = false,
    this.whiteLabelClientId,
    this.isHotfix = false,
    this.previousReleaseId,
    this.approvals = const {},
    this.checksum,
    this.artifactUrl,
    this.failureReason,
    this.rollbackTargetId,
  });

  final String id;
  final String version;
  final int buildNumber;
  final String flavor;
  final ReleasePlatform platform;
  final ReleaseEnvironment environment;
  final ReleaseStatus status;
  final DateTime createdAt;
  final int rolloutPercentage;
  final String? rolloutRegion;
  final String? tenantId;
  final bool isWhiteLabel;
  final String? whiteLabelClientId;
  final bool isHotfix;
  final String? previousReleaseId;
  final Map<ApprovalRole, ApprovalState> approvals;
  final String? checksum;
  final String? artifactUrl;
  final String? failureReason;
  final String? rollbackTargetId;

  bool get isReadyForRelease =>
      status == ReleaseStatus.approved &&
      approvals.values.every((a) => a == ApprovalState.approved);

  bool get isRollingOut =>
      status == ReleaseStatus.staged && rolloutPercentage > 0;

  bool get isFullyDeployed =>
      status == ReleaseStatus.completed && rolloutPercentage == 100;

  bool get isRolledBack => status == ReleaseStatus.rolledBack;

  bool get canPromote => status == ReleaseStatus.approved;

  bool get canRollback =>
      status == ReleaseStatus.staged || status == ReleaseStatus.completed;

  bool get isFailed => status == ReleaseStatus.failed;

  bool get canRetry => isFailed || status == ReleaseStatus.rolledBack;

  ReleaseState copyWith({
    ReleaseStatus? status,
    int? rolloutPercentage,
    Map<ApprovalRole, ApprovalState>? approvals,
    String? failureReason,
    String? artifactUrl,
    String? checksum,
  }) {
    return ReleaseState(
      id: id,
      version: version,
      buildNumber: buildNumber,
      flavor: flavor,
      platform: platform,
      environment: environment,
      status: status ?? this.status,
      createdAt: createdAt,
      rolloutPercentage: rolloutPercentage ?? this.rolloutPercentage,
      rolloutRegion: rolloutRegion,
      tenantId: tenantId,
      isWhiteLabel: isWhiteLabel,
      whiteLabelClientId: whiteLabelClientId,
      isHotfix: isHotfix,
      previousReleaseId: previousReleaseId,
      approvals: approvals ?? this.approvals,
      checksum: checksum ?? this.checksum,
      artifactUrl: artifactUrl ?? this.artifactUrl,
      failureReason: failureReason ?? this.failureReason,
      rollbackTargetId: rollbackTargetId,
    );
  }
}

enum ReleasePlatform {
  android,
  ios,
  web,
}

enum ReleaseEnvironment {
  dev,
  qa,
  staging,
  demo,
  production,
  whiteLabel,
}

enum ReleaseStatus {
  drafted,
  validated,
  signed,
  approved,
  staged,
  paused,
  rollingOut,
  completed,
  failed,
  rollbackInitiated,
  rolledBack,
  rejected,
}

enum ApprovalRole {
  engineering,
  product,
  compliance,
  client,
  security,
}

enum ApprovalState {
  pending,
  approved,
  rejected,
}
