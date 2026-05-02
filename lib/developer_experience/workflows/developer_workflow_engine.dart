import 'package:flutter_production_kit/developer_experience/domain/entities/dx_result.dart';
import 'package:flutter_production_kit/developer_experience/domain/exceptions/dx_exception.dart';
import 'package:flutter_production_kit/developer_experience/domain/repositories/dx_repositories.dart';

/// Developer workflow engine — guides developers through common workflows.
///
/// Design rationale:
/// - Workflows are step-by-step with clear guidance.
/// - Each workflow has a defined start, steps, and completion criteria.
/// - Workflows can be paused and resumed.
/// - Workflow progress is tracked for analytics.
///
/// Available workflows:
/// - new_project — Bootstrap a new project from scratch.
/// - add_module — Add a module to an existing project.
/// - setup_flavors — Configure flavor environments.
/// - setup_billing — Integrate billing and subscriptions.
/// - setup_offline — Configure offline sync.
/// - setup_multi_tenant — Configure multi-tenant isolation.
/// - migrate_version — Upgrade to a new framework version.
/// - deploy_production — Deploy to production safely.
class DeveloperWorkflowEngine {
  const DeveloperWorkflowEngine({
    required IOnboardingRepository onboardingRepository,
  }) : _onboardingRepository = onboardingRepository;

  final IOnboardingRepository _onboardingRepository;

  /// Start a workflow.
  Future<DXResult> startWorkflow({
    required String workflowName,
    required String projectName,
    Map<String, String> params = const {},
  }) async {
    final workflow = _getWorkflow(workflowName);
    if (workflow == null) {
      return DoctorCheckFailed(
        operation: 'start_workflow',
        failedChecks: ['Unknown workflow: $workflowName'],
        remediation: ['Available: new_project, add_module, setup_flavors, '
            'setup_billing, setup_offline, setup_multi_tenant, migrate_version, '
            'deploy_production'],
      );
    }

    final state = DeveloperWorkflowState(
      projectName: projectName,
      currentStep: workflow.steps.first,
      completedSteps: const [],
      totalSteps: workflow.steps.length,
      startedAt: DateTime.now(),
      lastActionAt: DateTime.now(),
    );

    await _onboardingRepository.saveWorkflow(state);

    return SetupCompletedSuccessfully(
      operation: 'start_workflow',
      projectPath: projectName,
      nextSteps: workflow.steps,
    );
  }

  /// Advance to the next step in a workflow.
  Future<DeveloperWorkflowState> advanceWorkflow({
    required String projectName,
  }) async {
    final state = await _onboardingRepository.getWorkflow(projectName);
    if (state == null) {
      throw OnboardingIncompleteException(
        message: 'No active workflow found for project: $projectName',
        missingSteps: ['Start a workflow first'],
      );
    }

    final workflow = _getWorkflow(state.currentStep);
    if (workflow == null) {
      throw WorkflowErrorException(
        message: 'Unknown workflow step: ${state.currentStep}',
        workflowName: projectName,
        step: state.currentStep,
      );
    }

    final currentIndex = workflow.steps.indexOf(state.currentStep);
    if (currentIndex < workflow.steps.length - 1) {
      return state.advanceTo(workflow.steps[currentIndex + 1]);
    }

    return state.copyWith(
      currentStep: 'completed',
      completedSteps: [...state.completedSteps, state.currentStep],
    );
  }

  /// Get workflow by name.
  WorkflowConfig? _getWorkflow(String name) {
    return _workflows[name];
  }

  static const Map<String, WorkflowConfig> _workflows = {
    'new_project': WorkflowConfig(
      name: 'new_project',
      description: 'Bootstrap a new project from scratch',
      steps: [
        'validate_system',
        'create_project',
        'configure_flavors',
        'initialize_modules',
        'setup_cicd',
        'validate_setup',
      ],
      estimatedTimeMinutes: 30,
    ),
    'add_module': WorkflowConfig(
      name: 'add_module',
      description: 'Add a module to an existing project',
      steps: [
        'select_module',
        'add_dependencies',
        'generate_boilerplate',
        'register_in_di',
        'test_integration',
      ],
      estimatedTimeMinutes: 15,
    ),
    'setup_flavors': WorkflowConfig(
      name: 'setup_flavors',
      description: 'Configure flavor environments',
      steps: [
        'define_flavors',
        'create_config_files',
        'configure_schemas',
        'test_flavor_switching',
      ],
      estimatedTimeMinutes: 20,
    ),
    'setup_billing': WorkflowConfig(
      name: 'setup_billing',
      description: 'Integrate billing and subscriptions',
      steps: [
        'add_billing_module',
        'configure_plans',
        'setup_entitlements',
        'integrate_payment',
        'test_billing_flow',
      ],
      estimatedTimeMinutes: 45,
    ),
    'setup_offline': WorkflowConfig(
      name: 'setup_offline',
      description: 'Configure offline sync',
      steps: [
        'add_offline_module',
        'configure_sync_strategy',
        'define_syncable_models',
        'test_sync_flow',
        'configure_conflict_resolution',
      ],
      estimatedTimeMinutes: 30,
    ),
    'migrate_version': WorkflowConfig(
      name: 'migrate_version',
      description: 'Upgrade to a new framework version',
      steps: [
        'check_compatibility',
        'backup_project',
        'update_dependencies',
        'run_migration_steps',
        'test_functionality',
        'validate_upgrade',
      ],
      estimatedTimeMinutes: 60,
    ),
    'deploy_production': WorkflowConfig(
      name: 'deploy_production',
      description: 'Deploy to production safely',
      steps: [
        'run_tests',
        'run_analyzer',
        'build_release',
        'sign_artifact',
        'staged_rollout',
        'monitor_health',
        'complete_deployment',
      ],
      estimatedTimeMinutes: 90,
    ),
  };
}

/// Workflow configuration — represents a developer workflow.
class WorkflowConfig {
  const WorkflowConfig({
    required this.name,
    required this.description,
    required this.steps,
    required this.estimatedTimeMinutes,
  });

  final String name;
  final String description;
  final List<String> steps;
  final int estimatedTimeMinutes;
}
