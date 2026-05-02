import 'package:flutter_production_kit/release_engineering/domain/entities/approval_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/deployment_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/rollout_state.dart';

/// Repository interface for release data access.
abstract class IReleaseRepository {
  Future<ReleaseState?> getById(String releaseId);
  Future<List<ReleaseState>> getByFlavor(String flavor);
  Future<List<ReleaseState>> getByEnvironment(String environment);
  Future<List<ReleaseState>> getActiveReleases();
  Future<void> save(ReleaseState release);
  Future<void> updateStatus(String releaseId, ReleaseStatus status);
}

/// Repository interface for rollout data access.
abstract class IRolloutRepository {
  Future<RolloutState?> getActiveRollout(String releaseId);
  Future<List<RolloutState>> getRolloutsByEnvironment(String environment);
  Future<void> save(RolloutState rollout);
  Future<void> updatePercentage(String rolloutId, int percentage);
  Future<void> pauseRollout(String rolloutId, String reason);
  Future<void> resumeRollout(String rolloutId);
}

/// Repository interface for deployment data access.
abstract class IDeploymentRepository {
  Future<DeploymentState?> getById(String deploymentId);
  Future<List<DeploymentState>> getByReleaseId(String releaseId);
  Future<List<DeploymentState>> getByEnvironment(String environment);
  Future<void> save(DeploymentState deployment);
  Future<void> updateStatus(String deploymentId, DeploymentStatus status);
}

/// Repository interface for approval data access.
abstract class IApprovalRepository {
  Future<List<ApprovalRecord>> getByReleaseId(String releaseId);
  Future<ApprovalRecord?> getByReleaseIdAndRole(String releaseId, String role);
  Future<void> save(ApprovalRecord record);
  Future<List<ApprovalRecord>> getPendingApprovals(String role);
}

/// Repository interface for signing data access.
abstract class ISigningRepository {
  Future<Map<String, String>?> getSigningKeyConfig(String environment, String platform);
  Future<void> recordSigningEvent({
    required String releaseId,
    required String platform,
    required String status,
    required DateTime timestamp,
    String? keyAlias,
    String? checksum,
  });
  Future<List<Map<String, String>>> getSigningHistory(String releaseId);
}
