import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/developer_experience/cli/flutter_runtime_cli.dart';
import 'package:flutter_production_kit/developer_experience/contributors/contributor_onboarding_engine.dart';
import 'package:flutter_production_kit/developer_experience/diagnostics/developer_diagnostics_engine.dart';
import 'package:flutter_production_kit/developer_experience/docs/dx_documentation_engine.dart';
import 'package:flutter_production_kit/developer_experience/domain/repositories/dx_repositories.dart';
import 'package:flutter_production_kit/developer_experience/examples/reference_app_engine.dart';
import 'package:flutter_production_kit/developer_experience/migrations/migration_assistant.dart';
import 'package:flutter_production_kit/developer_experience/onboarding/project_bootstrap_engine.dart';
import 'package:flutter_production_kit/developer_experience/standards/architecture_guardrails.dart';
import 'package:flutter_production_kit/developer_experience/templates/starter_template_manager.dart';
import 'package:flutter_production_kit/developer_experience/workflows/developer_workflow_engine.dart';
import 'package:get_it/get_it.dart';

/// Developer experience module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All developer experience dependencies are registered here in one place.
/// - Repository interfaces are injected — concrete implementations depend on storage backend.
/// - ProjectBootstrapEngine handles one-command project initialization.
/// - FlutterRuntimeCLI provides delightful CLI commands.
/// - DeveloperDiagnosticsEngine provides clear debugging guidance.
/// - MigrationAssistant guides developers through version upgrades.
/// - ArchitectureGuardrails enforces architecture standards.
///
/// Usage:
/// ```dart
/// DeveloperExperienceModule.register(getIt,
///   onboardingRepository: myOnboardingRepo,
///   diagnosticRepository: myDiagnosticRepo,
///   templateRepository: myTemplateRepo,
///   migrationRepository: myMigrationRepo,
/// );
///
/// // Later in code:
/// final bootstrapEngine = getIt<ProjectBootstrapEngine>();
/// final cli = getIt<FlutterRuntimeCLI>();
/// final diagnostics = getIt<DeveloperDiagnosticsEngine>();
/// ```
abstract final class DeveloperExperienceModule {
  DeveloperExperienceModule._();

  static const String _tag = 'DeveloperExperienceModule';

  static void register(
    GetIt getIt, {
    required IOnboardingRepository onboardingRepository,
    required IDiagnosticRepository diagnosticRepository,
    required ITemplateRepository templateRepository,
    required DXMigrationRepository migrationRepository,
    ProjectBootstrapEngine? bootstrapEngine,
    ArchitectureGuardrails? guardrails,
    DXDocumentationEngine? docsEngine,
    ContributorOnboardingEngine? contributorOnboarding,
  }) {
    AppLogger.info(_tag, 'Registering developer experience module...');

    // ── Onboarding ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ProjectBootstrapEngine>(
      () => bootstrapEngine ?? ProjectBootstrapEngine(
        onboardingRepository: onboardingRepository,
      ),
    );

    getIt.registerLazySingleton<SetupValidationEngine>(
      () => const SetupValidationEngine(),
    );

    // ── CLI ──────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<FlutterRuntimeCLI>(
      () => const FlutterRuntimeCLI(),
    );

    getIt.registerLazySingleton<ProjectGenerator>(
      () => const ProjectGenerator(),
    );

    // ── Templates ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<StarterTemplateManager>(
      () => const StarterTemplateManager(),
    );

    // ── Examples ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ReferenceAppEngine>(
      () => const ReferenceAppEngine(),
    );

    // ── Migrations ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<MigrationAssistant>(
      () => MigrationAssistant(
        migrationRepository: migrationRepository,
      ),
    );

    getIt.registerLazySingleton<UpgradeSafetyEngine>(
      () => const UpgradeSafetyEngine(),
    );

    // ── Diagnostics ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<DeveloperDiagnosticsEngine>(
      () => DeveloperDiagnosticsEngine(
        diagnosticRepository: diagnosticRepository,
      ),
    );

    getIt.registerLazySingleton<FailureExplainer>(
      () => const FailureExplainer(),
    );

    // ── Documentation ────────────────────────────────────────────────────────

    getIt.registerLazySingleton<DXDocumentationEngine>(
      () => docsEngine ?? const DXDocumentationEngine(),
    );

    getIt.registerLazySingleton<OnboardingDocsManager>(
      () => const OnboardingDocsManager(),
    );

    // ── Workflows ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<DeveloperWorkflowEngine>(
      () => DeveloperWorkflowEngine(
        onboardingRepository: onboardingRepository,
      ),
    );

    // ── Contributors ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ContributorOnboardingEngine>(
      () => contributorOnboarding ?? const ContributorOnboardingEngine(),
    );

    // ── Standards ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ArchitectureGuardrails>(
      () => guardrails ?? const ArchitectureGuardrails(),
    );

    AppLogger.info(_tag, 'Developer experience module registration complete.');
  }

  /// Unregister all developer experience dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<ProjectBootstrapEngine>();
    getIt.unregister<SetupValidationEngine>();
    getIt.unregister<FlutterRuntimeCLI>();
    getIt.unregister<ProjectGenerator>();
    getIt.unregister<StarterTemplateManager>();
    getIt.unregister<ReferenceAppEngine>();
    getIt.unregister<MigrationAssistant>();
    getIt.unregister<UpgradeSafetyEngine>();
    getIt.unregister<DeveloperDiagnosticsEngine>();
    getIt.unregister<FailureExplainer>();
    getIt.unregister<DXDocumentationEngine>();
    getIt.unregister<OnboardingDocsManager>();
    getIt.unregister<DeveloperWorkflowEngine>();
    getIt.unregister<ContributorOnboardingEngine>();
    getIt.unregister<ArchitectureGuardrails>();

    AppLogger.info(_tag, 'Developer experience module unregistered.');
  }
}
