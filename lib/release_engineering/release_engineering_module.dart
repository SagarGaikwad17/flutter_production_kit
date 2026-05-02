import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/release_engineering/approvals/release_approval_engine.dart';
import 'package:flutter_production_kit/release_engineering/audits/deployment_audit_engine.dart';
import 'package:flutter_production_kit/release_engineering/compliance/release_compliance_manager.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';
import 'package:flutter_production_kit/release_engineering/environments/environment_guard.dart';
import 'package:flutter_production_kit/release_engineering/flavors/flavor_release_validator.dart';
import 'package:flutter_production_kit/release_engineering/pipelines/build_pipeline_manager.dart';
import 'package:flutter_production_kit/release_engineering/pipelines/release_orchestrator.dart';
import 'package:flutter_production_kit/release_engineering/rollback/rollback_manager.dart';
import 'package:flutter_production_kit/release_engineering/rollout/staged_rollout_engine.dart';
import 'package:flutter_production_kit/release_engineering/signing/secret_protection_engine.dart';
import 'package:flutter_production_kit/release_engineering/signing/signing_manager.dart';
import 'package:flutter_production_kit/release_engineering/tracing/release_trace_engine.dart';
import 'package:get_it/get_it.dart';

/// Release engineering module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All release engineering dependencies are registered here in one place.
/// - Repository interfaces are injected — concrete implementations depend on storage backend.
/// - FlavorReleaseValidator prevents wrong-flavor releases at compile-time.
/// - SigningManager handles secure artifact signing with secret masking.
/// - StagedRolloutEngine manages incremental deployment with health gates.
/// - RollbackManager provides deterministic rollback paths.
/// - ReleaseApprovalEngine gates releases behind multi-role approvals.
/// - EnvironmentGuard prevents cross-environment contamination.
///
/// Usage:
/// ```dart
/// ReleaseEngineeringModule.register(getIt,
///   releaseRepository: myReleaseRepo,
///   rolloutRepository: myRolloutRepo,
///   deploymentRepository: myDeploymentRepo,
///   approvalRepository: myApprovalRepo,
///   signingRepository: mySigningRepo,
/// );
///
/// // Later in code:
/// final buildPipelineManager = getIt<BuildPipelineManager>();
/// final releaseOrchestrator = getIt<ReleaseOrchestrator>();
/// final stagedRolloutEngine = getIt<StagedRolloutEngine>();
/// final rollbackManager = getIt<RollbackManager>();
/// ```
abstract final class ReleaseEngineeringModule {
  ReleaseEngineeringModule._();

  static const String _tag = 'ReleaseEngineeringModule';

  static void register(
    GetIt getIt, {
    required IReleaseRepository releaseRepository,
    required IRolloutRepository rolloutRepository,
    required IDeploymentRepository deploymentRepository,
    required IApprovalRepository approvalRepository,
    required ISigningRepository signingRepository,
    FlavorReleaseValidator? flavorValidator,
    SecretProtectionEngine? secretEngine,
    EnvironmentGuard? environmentGuard,
    ReleaseComplianceManager? complianceManager,
    List<int>? rolloutIncrements,
    List<String>? productionRequiredRoles,
  }) {
    AppLogger.info(_tag, 'Registering release engineering module...');

    // ── Secret Protection ────────────────────────────────────────────────────

    getIt.registerLazySingleton<SecretProtectionEngine>(
      () => secretEngine ?? const SecretProtectionEngine(),
    );

    // ── Flavor Validation ────────────────────────────────────────────────────

    getIt.registerLazySingleton<FlavorReleaseValidator>(
      () => flavorValidator ?? const FlavorReleaseValidator(),
    );

    // ── Environment Guard ────────────────────────────────────────────────────

    getIt.registerLazySingleton<EnvironmentGuard>(
      () => environmentGuard ?? const EnvironmentGuard(),
    );

    // ── Compliance ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ReleaseComplianceManager>(
      () => complianceManager ?? const ReleaseComplianceManager(),
    );

    // ── Signing ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SigningManager>(
      () => SigningManager(
        signingRepository: signingRepository,
      ),
    );

    // ── Pipelines ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<BuildPipelineManager>(
      () => BuildPipelineManager(
        releaseRepository: releaseRepository,
        deploymentRepository: deploymentRepository,
      ),
    );

    getIt.registerLazySingleton<ReleaseOrchestrator>(
      () => ReleaseOrchestrator(
        releaseRepository: releaseRepository,
        flavorValidator: getIt<FlavorReleaseValidator>(),
        signingManager: getIt<SigningManager>(),
      ),
    );

    // ── Rollout ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<StagedRolloutEngine>(
      () => StagedRolloutEngine(
        rolloutRepository: rolloutRepository,
        rolloutIncrements: rolloutIncrements ?? const <int>[1, 10, 25, 50, 100],
      ),
    );

    // ── Rollback ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RollbackManager>(
      () => RollbackManager(
        releaseRepository: releaseRepository,
        deploymentRepository: deploymentRepository,
      ),
    );

    // ── Approvals ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ReleaseApprovalEngine>(
      () => ReleaseApprovalEngine(
        releaseRepository: releaseRepository,
        approvalRepository: approvalRepository,
        productionRequiredRoles:
            productionRequiredRoles ?? const <String>['engineering', 'product', 'compliance', 'security'],
      ),
    );

    // ── Audits ───────────────────────────────────────────────────────────────

    getIt.registerFactory<DeploymentAuditEngine>(
      () => DeploymentAuditEngine(
        onAuditEvent: (event) {
          AppLogger.info(
            _tag,
            'Deployment audit: ${event.eventType} (release: ${event.releaseId})',
          );
        },
      ),
    );

    // ── Tracing ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ReleaseTraceEngine>(
      () => const ReleaseTraceEngine(),
    );

    AppLogger.info(_tag, 'Release engineering module registration complete.');
  }

  /// Unregister all release engineering dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<SecretProtectionEngine>();
    getIt.unregister<FlavorReleaseValidator>();
    getIt.unregister<EnvironmentGuard>();
    getIt.unregister<ReleaseComplianceManager>();
    getIt.unregister<SigningManager>();
    getIt.unregister<BuildPipelineManager>();
    getIt.unregister<ReleaseOrchestrator>();
    getIt.unregister<StagedRolloutEngine>();
    getIt.unregister<RollbackManager>();
    getIt.unregister<ReleaseApprovalEngine>();
    getIt.unregister<DeploymentAuditEngine>();
    getIt.unregister<ReleaseTraceEngine>();

    AppLogger.info(_tag, 'Release engineering module unregistered.');
  }
}
