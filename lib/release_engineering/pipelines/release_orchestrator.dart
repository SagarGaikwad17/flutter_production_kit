import 'package:flutter_production_kit/release_engineering/domain/entities/release_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/exceptions/release_exception.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';
import 'package:flutter_production_kit/release_engineering/flavors/flavor_release_validator.dart';
import 'package:flutter_production_kit/release_engineering/signing/signing_manager.dart';

/// Release orchestrator — coordinates the full release lifecycle.
///
/// Design rationale:
/// - Orchestrates build → validate → sign → approve → deploy → rollout.
/// - Each stage is validated before proceeding.
/// - Flavor validation prevents wrong-flavor releases.
/// - Signing validation prevents unsigned releases.
/// - Approval validation prevents unauthorized releases.
/// - Rollout validation prevents unsafe deployments.
///
/// Lifecycle:
///   1. Build pipeline produces artifact.
///   2. Flavor validator ensures correct flavor.
///   3. Signing manager signs artifact.
///   4. Approval engine gates release.
///   5. Rollout engine deploys incrementally.
///   6. Health gates monitor rollout.
///   7. Rollback manager can revert on failure.
class ReleaseOrchestrator {
  const ReleaseOrchestrator({
    required IReleaseRepository releaseRepository,
    required FlavorReleaseValidator flavorValidator,
    required SigningManager signingManager,
  })  : _releaseRepository = releaseRepository,
        _flavorValidator = flavorValidator,
        _signingManager = signingManager;

  final IReleaseRepository _releaseRepository;
  final FlavorReleaseValidator _flavorValidator;
  final SigningManager _signingManager;

  /// Promote a release through the full pipeline.
  Future<ReleaseResult> promoteRelease({
    required String releaseId,
    required String expectedFlavor,
    required ReleaseEnvironment expectedEnvironment,
    required List<String> requiredApprovalRoles,
  }) async {
    final release = await _releaseRepository.getById(releaseId);
    if (release == null) {
      throw const ReleaseNotFoundException(
        message: 'Release not found',
      );
    }

    // Step 1: Validate flavor
    final flavorResult = _flavorValidator.validate({
      'buildFlavor': release.flavor,
      'expectedFlavor': expectedFlavor,
      'environment': expectedEnvironment.name,
    });

    if (!flavorResult.isValid) {
      return BlockedByFlavorMismatch(
        releaseId: releaseId,
        expectedFlavor: expectedFlavor,
        actualFlavor: release.flavor,
        environment: expectedEnvironment.name,
      );
    }

    // Step 2: Sign artifact
    final signingResult = await _signingManager.signArtifact(
      releaseId: releaseId,
      platform: release.platform,
      environment: expectedEnvironment,
    );

    if (!signingResult.isSuccess) {
      return _mapSigningToReleaseResult(signingResult, releaseId, release.platform.name);
    }

    // Step 3: Transition to signed
    await _releaseRepository.updateStatus(releaseId, ReleaseStatus.signed);

    // Step 4: Check approvals (delegate to ReleaseApprovalEngine)
    // This is done externally after signing.

    return ReleaseValidated(
      releaseId: releaseId,
      flavor: release.flavor,
      checksum: release.checksum ?? '',
    );
  }

  /// Execute an emergency hotfix release.
  Future<ReleaseResult> executeEmergencyHotfix({
    required String releaseId,
    required String expectedFlavor,
    required ReleaseEnvironment expectedEnvironment,
    required String severity,
  }) async {
    final release = await _releaseRepository.getById(releaseId);
    if (release == null) {
      throw const ReleaseNotFoundException(
        message: 'Release not found for hotfix',
      );
    }

    // Hotfix still requires flavor validation.
    final flavorResult = _flavorValidator.validate({
      'buildFlavor': release.flavor,
      'expectedFlavor': expectedFlavor,
      'environment': expectedEnvironment.name,
    });

    if (!flavorResult.isValid) {
      return BlockedByFlavorMismatch(
        releaseId: releaseId,
        expectedFlavor: expectedFlavor,
        actualFlavor: release.flavor,
        environment: expectedEnvironment.name,
      );
    }

    // Hotfix skips some approval gates but still requires signing.
    final signingResult = await _signingManager.signArtifact(
      releaseId: releaseId,
      platform: release.platform,
      environment: expectedEnvironment,
    );

    if (!signingResult.isSuccess) {
      return BlockedBySigningFailure(
        releaseId: releaseId,
        reason: 'Hotfix signing failed',
        platform: release.platform.name,
      );
    }

    // Mark as hotfix and transition to approved.
    await _releaseRepository.updateStatus(releaseId, ReleaseStatus.approved);

    throw EmergencyReleaseException(
      message: 'Emergency hotfix $releaseId proceeding with elevated risk',
      releaseId: releaseId,
      severity: severity,
    );
  }

  ReleaseResult _mapSigningToReleaseResult(
    dynamic signingResult,
    String releaseId,
    String platformName,
  ) {
    if (signingResult is BlockedBySigningFailure) {
      return signingResult;
    }
    return BlockedBySigningFailure(
      releaseId: releaseId,
      reason: 'Signing failed for platform $platformName',
      platform: platformName,
    );
  }
}
