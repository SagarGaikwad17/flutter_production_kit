import 'package:flutter_production_kit/release_engineering/domain/entities/deployment_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';

/// Build pipeline manager — orchestrates deterministic build pipelines.
///
/// Design rationale:
/// - Pipeline is a sequence of validated steps.
/// - Each step produces an artifact or fails explicitly.
/// - Flavor validation happens before any build artifacts are produced.
/// - Environment validation prevents cross-environment contamination.
/// - Secret-safe — no credentials logged or exposed.
///
/// Pipeline steps:
///   1. Validate flavor configuration.
///   2. Validate environment configuration.
///   3. Validate white-label configuration (if applicable).
///   4. Build artifact.
///   5. Generate checksum.
///   6. Sign artifact.
///   7. Upload artifact.
///   8. Record deployment state.
class BuildPipelineManager {
  const BuildPipelineManager({
    required IReleaseRepository releaseRepository,
    required IDeploymentRepository deploymentRepository,
  })  : _releaseRepository = releaseRepository,
        _deploymentRepository = deploymentRepository;

  final IReleaseRepository _releaseRepository;
  final IDeploymentRepository _deploymentRepository;

  /// Execute a full build pipeline.
  Future<ReleaseResult> executePipeline({
    required String version,
    required int buildNumber,
    required String flavor,
    required ReleasePlatform platform,
    required ReleaseEnvironment environment,
    String? rolloutRegion,
    String? tenantId,
    bool isWhiteLabel = false,
    String? whiteLabelClientId,
    bool isHotfix = false,
  }) async {
    final releaseId = _generateReleaseId();
    final now = DateTime.now();

    ReleaseState release = ReleaseState(
      id: releaseId,
      version: version,
      buildNumber: buildNumber,
      flavor: flavor,
      platform: platform,
      environment: environment,
      status: ReleaseStatus.drafted,
      createdAt: now,
      rolloutRegion: rolloutRegion,
      tenantId: tenantId,
      isWhiteLabel: isWhiteLabel,
      whiteLabelClientId: whiteLabelClientId,
      isHotfix: isHotfix,
    );

    try {
      // Step 1: Draft release
      await _releaseRepository.save(release);

      // Step 2: Validate flavor (delegate to FlavorReleaseValidator)
      // This is done externally before calling this method.

      // Step 3: Transition to validated
      release = release.copyWith(status: ReleaseStatus.validated);
      await _releaseRepository.save(release);

      // Step 4: Build artifact (delegate to platform-specific builder)
      final artifactUrl = await _buildArtifact(
        flavor: flavor,
        platform: platform,
        environment: environment,
        isWhiteLabel: isWhiteLabel,
        whiteLabelClientId: whiteLabelClientId,
      );

      // Step 5: Generate checksum
      final checksum = await _generateChecksum(artifactUrl);

      release = release.copyWith(
        status: ReleaseStatus.validated,
        artifactUrl: artifactUrl,
        checksum: checksum,
      );
      await _releaseRepository.save(release);

      // Step 6: Record deployment state
      final deployment = DeploymentState(
        id: _generateDeploymentId(),
        releaseId: releaseId,
        environment: environment.name,
        status: DeploymentStatus.validating,
        createdAt: now,
      );
      await _deploymentRepository.save(deployment);

      return ReleaseValidated(
        releaseId: releaseId,
        flavor: flavor,
        checksum: checksum,
      );
    } catch (e) {
      await _releaseRepository.updateStatus(releaseId, ReleaseStatus.failed);
      rethrow;
    }
  }

  /// Build a platform-specific artifact.
  Future<String> _buildArtifact({
    required String flavor,
    required ReleasePlatform platform,
    required ReleaseEnvironment environment,
    required bool isWhiteLabel,
    String? whiteLabelClientId,
  }) async {
    final platformName = platform.name;
    final flavorName = flavor;
    final envName = environment.name;

    // In production, this would invoke the actual build system.
    // For now, return a deterministic artifact path.
    final wlSuffix = isWhiteLabel && whiteLabelClientId != null
        ? '_${whiteLabelClientId}'
        : '';

    return 'artifacts/${flavorName}_${platformName}_${envName}${wlSuffix}.apk';
  }

  /// Generate a deterministic checksum for an artifact.
  Future<String> _generateChecksum(String artifactUrl) async {
    // In production, this would compute SHA-256 of the artifact.
    return 'sha256:${artifactUrl.hashCode.toRadixString(16)}';
  }

  String _generateReleaseId() {
    return 'rel_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateDeploymentId() {
    return 'dep_${DateTime.now().millisecondsSinceEpoch}';
  }
}
