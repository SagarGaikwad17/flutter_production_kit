import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/sdk_strategy/adoption/developer_adoption_engine.dart';
import 'package:flutter_production_kit/sdk_strategy/contributors/contribution_policy.dart';
import 'package:flutter_production_kit/sdk_strategy/docs/documentation_engine.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/repositories/sdk_repositories.dart';
import 'package:flutter_production_kit/sdk_strategy/examples/example_app_strategy.dart';
import 'package:flutter_production_kit/sdk_strategy/governance/maintainer_model.dart';
import 'package:flutter_production_kit/sdk_strategy/migration/migration_engine.dart';
import 'package:flutter_production_kit/sdk_strategy/packages/package_boundary_manager.dart';
import 'package:flutter_production_kit/sdk_strategy/publishing/pubdev_release_manager.dart';
import 'package:flutter_production_kit/sdk_strategy/trust/enterprise_readiness_framework.dart';
import 'package:flutter_production_kit/sdk_strategy/versioning/semver_manager.dart';
import 'package:get_it/get_it.dart';

/// SDK strategy module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All SDK strategy dependencies are registered here in one place.
/// - Repository interfaces are injected — concrete implementations depend on storage backend.
/// - PackageBoundaryManager enforces modular package boundaries.
/// - SemverManager enforces semantic versioning discipline.
/// - DocumentationEngine ensures documentation completeness.
/// - PubDevReleaseManager gates pub.dev publishing readiness.
/// - MigrationEngine manages version-to-version migration paths.
/// - DeveloperAdoptionEngine tracks adoption metrics.
/// - EnterpriseReadinessFramework evaluates enterprise readiness.
///
/// Usage:
/// ```dart
/// SDKStrategyModule.register(getIt,
///   packageRepository: myPackageRepo,
///   versionRepository: myVersionRepo,
///   migrationRepository: myMigrationRepo,
///   contributionRepository: myContributionRepo,
///   adoptionRepository: myAdoptionRepo,
///   documentationRepository: myDocRepo,
/// );
///
/// // Later in code:
/// final packageBoundaryManager = getIt<PackageBoundaryManager>();
/// final semverManager = getIt<SemverManager>();
/// final migrationEngine = getIt<MigrationEngine>();
/// ```
abstract final class SDKStrategyModule {
  SDKStrategyModule._();

  static const String _tag = 'SDKStrategyModule';

  static void register(
    GetIt getIt, {
    required IPackageRepository packageRepository,
    required IVersionRepository versionRepository,
    required IMigrationRepository migrationRepository,
    required IContributionRepository contributionRepository,
    required IAdoptionRepository adoptionRepository,
    required IDocumentationRepository documentationRepository,
    SemverManager? semverManager,
    PackageBoundaryManager? boundaryManager,
    BreakingChangePolicy? breakingChangePolicy,
    ExampleAppStrategy? exampleAppStrategy,
    ContributionPolicy? contributionPolicy,
    ReviewGuardrails? reviewGuardrails,
    MaintainerModel? maintainerModel,
    EnterpriseReadinessFramework? enterpriseFramework,
  }) {
    AppLogger.info(_tag, 'Registering SDK strategy module...');

    // ── Package Boundaries ───────────────────────────────────────────────────

    getIt.registerLazySingleton<PackageBoundaryManager>(
      () => boundaryManager ?? const PackageBoundaryManager(),
    );

    getIt.registerLazySingleton<DependencyGraphPolicy>(
      () => const DependencyGraphPolicy(),
    );

    // ── Versioning ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SemverManager>(
      () => semverManager ?? const SemverManager(),
    );

    getIt.registerLazySingleton<BreakingChangePolicy>(
      () => breakingChangePolicy ?? const BreakingChangePolicy(),
    );

    // ── Documentation ────────────────────────────────────────────────────────

    getIt.registerLazySingleton<DocumentationEngine>(
      () => DocumentationEngine(
        docRepository: documentationRepository,
      ),
    );

    getIt.registerLazySingleton<ArchitectureDocsStrategy>(
      () => const ArchitectureDocsStrategy(),
    );

    // ── Examples ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ExampleAppStrategy>(
      () => exampleAppStrategy ?? const ExampleAppStrategy(),
    );

    // ── Contributors ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ContributionPolicy>(
      () => contributionPolicy ?? const ContributionPolicy(),
    );

    getIt.registerLazySingleton<ReviewGuardrails>(
      () => reviewGuardrails ?? const ReviewGuardrails(),
    );

    // ── Governance ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<MaintainerModel>(
      () => maintainerModel ?? const MaintainerModel(),
    );

    // ── Migration ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<MigrationEngine>(
      () => MigrationEngine(
        migrationRepository: migrationRepository,
      ),
    );

    getIt.registerLazySingleton<UpgradePlaybookManager>(
      () => const UpgradePlaybookManager(),
    );

    // ── Publishing ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<PubDevReleaseManager>(
      () => PubDevReleaseManager(
        packageRepository: packageRepository,
      ),
    );

    // ── Adoption ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<DeveloperAdoptionEngine>(
      () => DeveloperAdoptionEngine(
        adoptionRepository: adoptionRepository,
      ),
    );

    // ── Trust ────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<EnterpriseReadinessFramework>(
      () => enterpriseFramework ?? const EnterpriseReadinessFramework(),
    );

    AppLogger.info(_tag, 'SDK strategy module registration complete.');
  }

  /// Unregister all SDK strategy dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<PackageBoundaryManager>();
    getIt.unregister<DependencyGraphPolicy>();
    getIt.unregister<SemverManager>();
    getIt.unregister<BreakingChangePolicy>();
    getIt.unregister<DocumentationEngine>();
    getIt.unregister<ArchitectureDocsStrategy>();
    getIt.unregister<ExampleAppStrategy>();
    getIt.unregister<ContributionPolicy>();
    getIt.unregister<ReviewGuardrails>();
    getIt.unregister<MaintainerModel>();
    getIt.unregister<MigrationEngine>();
    getIt.unregister<UpgradePlaybookManager>();
    getIt.unregister<PubDevReleaseManager>();
    getIt.unregister<DeveloperAdoptionEngine>();
    getIt.unregister<EnterpriseReadinessFramework>();

    AppLogger.info(_tag, 'SDK strategy module unregistered.');
  }
}
