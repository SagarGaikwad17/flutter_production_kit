import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/approvals/approval_engine.dart';
import 'package:flutter_production_kit/forms/approvals/approval_state_manager.dart';
import 'package:flutter_production_kit/forms/drafts/draft_manager.dart';
import 'package:flutter_production_kit/forms/drafts/draft_recovery_manager.dart';
import 'package:flutter_production_kit/forms/domain/repositories/form_repositories.dart';
import 'package:flutter_production_kit/forms/engine/field_dependency_engine.dart';
import 'package:flutter_production_kit/forms/engine/form_engine.dart';
import 'package:flutter_production_kit/forms/persistence/form_persistence_manager.dart';
import 'package:flutter_production_kit/forms/policies/approval_policy.dart';
import 'package:flutter_production_kit/forms/policies/submission_policy.dart';
import 'package:flutter_production_kit/forms/validation/server_validation_reconciler.dart';
import 'package:flutter_production_kit/forms/validation/validation_engine.dart';
import 'package:flutter_production_kit/forms/workflows/step_transition_manager.dart';
import 'package:flutter_production_kit/forms/workflows/workflow_engine.dart';
import 'package:get_it/get_it.dart';

/// Form engine module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All form dependencies are registered here in one place.
/// - The FormEngine is the central orchestrator for all form operations.
/// - Repositories are backed by FormPersistenceManager by default.
/// - Engines are singletons — single evaluation point for validation, workflow, approval.
/// - Policies are composable — can be swapped for different business rules.
///
/// Usage:
/// ```dart
/// FormEngineModule.register(getIt, storageBackend: myStorage);
///
/// // Later in code:
/// final formEngine = getIt<FormEngine>();
/// final result = await formEngine.submit(
///   formId: 'expense_report',
///   values: formValues,
///   userId: 'user_123',
/// );
/// ```
abstract final class FormEngineModule {
  FormEngineModule._();

  static const String _tag = 'FormEngineModule';

  static void register(
    GetIt getIt, {
    required FormStorageBackend storageBackend,
    Duration autoSaveInterval = const Duration(seconds: 30),
    Map<String, CustomVisibilityEvaluator>? customVisibilityEvaluators,
    Map<String, CustomValidator>? customValidators,
    Map<String, String>? fieldKeyMappings,
  }) {
    AppLogger.info(_tag, 'Registering form engine module...');

    // ── Persistence ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<FormPersistenceManager>(
      () => FormPersistenceManager(storage: storageBackend),
    );

    getIt.registerLazySingleton<FormSchemaRepository>(
      () => getIt<FormPersistenceManager>(),
    );

    getIt.registerLazySingleton<FormDraftRepository>(
      () => getIt<FormPersistenceManager>(),
    );

    getIt.registerLazySingleton<ApprovalRepository>(
      () => getIt<FormPersistenceManager>(),
    );

    // ── Validation ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ValidationEngine>(
      () => ValidationEngine(customValidators: customValidators),
    );

    getIt.registerLazySingleton<ServerValidationReconciler>(
      () => ServerValidationReconciler(fieldKeyMappings: fieldKeyMappings),
    );

    // ── Dependency Engine ────────────────────────────────────────────────────

    getIt.registerLazySingleton<FieldDependencyEngine>(
      () => FieldDependencyEngine(
        customEvaluators: customVisibilityEvaluators,
      ),
    );

    // ── Workflow ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<StepTransitionManager>(
      () => const StepTransitionManager(),
    );

    getIt.registerLazySingleton<WorkflowEngine>(
      () => WorkflowEngine(
        transitionManager: getIt<StepTransitionManager>(),
      ),
    );

    // ── Drafts ───────────────────────────────────────────────────────────────

    getIt.registerFactory<DraftManager>(
      () => DraftManager(
        draftRepository: getIt<FormDraftRepository>(),
        autoSaveInterval: autoSaveInterval,
      ),
    );

    getIt.registerLazySingleton<DraftRecoveryManager>(
      () => DraftRecoveryManager(
        draftRepository: getIt<FormDraftRepository>(),
      ),
    );

    // ── Approvals ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ApprovalStateManager>(
      () => const ApprovalStateManager(),
    );

    getIt.registerLazySingleton<ApprovalEngine>(
      () => ApprovalEngine(
        approvalRepository: getIt<ApprovalRepository>(),
        stateManager: getIt<ApprovalStateManager>(),
      ),
    );

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SubmissionPolicy>(
      () => const SubmissionPolicy(),
    );

    getIt.registerLazySingleton<ApprovalPolicy>(
      () => const ApprovalPolicy(),
    );

    // ── Main Engine ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<FormEngine>(
      () => FormEngine(
        schemaRepository: getIt<FormSchemaRepository>(),
        draftRepository: getIt<FormDraftRepository>(),
        validationEngine: getIt<ValidationEngine>(),
        dependencyEngine: getIt<FieldDependencyEngine>(),
        autoSaveInterval: autoSaveInterval,
      ),
    );

    AppLogger.info(_tag, 'Form engine module registration complete.');
  }

  /// Unregister all form engine dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<FormEngine>();
    getIt.unregister<ValidationEngine>();
    getIt.unregister<ServerValidationReconciler>();
    getIt.unregister<FieldDependencyEngine>();
    getIt.unregister<WorkflowEngine>();
    getIt.unregister<StepTransitionManager>();
    getIt.unregister<DraftRecoveryManager>();
    getIt.unregister<ApprovalEngine>();
    getIt.unregister<ApprovalStateManager>();
    getIt.unregister<SubmissionPolicy>();
    getIt.unregister<ApprovalPolicy>();
    getIt.unregister<FormPersistenceManager>();
    getIt.unregister<FormSchemaRepository>();
    getIt.unregister<FormDraftRepository>();
    getIt.unregister<ApprovalRepository>();

    // DraftManager is a factory — no need to unregister.

    AppLogger.info(_tag, 'Form engine module unregistered.');
  }
}
