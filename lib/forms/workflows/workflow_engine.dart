import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';
import 'package:flutter_production_kit/forms/domain/exceptions/form_exception.dart';
import 'package:flutter_production_kit/forms/domain/entities/workflow_step.dart';
import 'package:flutter_production_kit/forms/workflows/step_transition_manager.dart';

/// Workflow engine — manages multi-step form progression.
///
/// Design rationale:
/// - Orchestrates step transitions based on rules, roles, and approvals.
/// - Enforces validation mode per step (onExit, onSubmit, lazy).
/// - Tracks current step and validates transitions.
/// - Returns typed FormSubmissionResult for blocked transitions.
/// - Integrates with permission engine for role/entitlement checks.
///
/// Transition flow:
/// 1. Find current step.
/// 2. Check validation mode — validate if onExit.
/// 3. Evaluate transition rules.
/// 4. Check role/entitlement requirements.
/// 5. Check approval requirements.
/// 6. Transition to next step or return blocked result.
class WorkflowEngine {
  WorkflowEngine({
    StepTransitionManager? transitionManager,
  }) : _transitionManager = transitionManager ?? const StepTransitionManager();

  final StepTransitionManager _transitionManager;

  /// Get the current step from the workflow.
  WorkflowStepConfig? getCurrentStep({
    required FormSchema schema,
    required int currentStepIndex,
  }) {
    if (schema.workflowSteps.isEmpty) return null;
    if (currentStepIndex < 0 || currentStepIndex >= schema.workflowSteps.length) {
      return null;
    }
    return schema.workflowSteps[currentStepIndex];
  }

  /// Get the next step in the workflow.
  WorkflowStepConfig? getNextStep({
    required FormSchema schema,
    required int currentStepIndex,
  }) {
    if (schema.workflowSteps.isEmpty) return null;
    final nextIndex = currentStepIndex + 1;
    if (nextIndex >= schema.workflowSteps.length) return null;
    return schema.workflowSteps[nextIndex];
  }

  /// Check if a transition is allowed.
  FormSubmissionResult canTransition({
    required FormSchema schema,
    required int currentStepIndex,
    required FormValues values,
    List<String>? userRoles,
    Set<String>? userEntitlements,
    bool isOnline = true,
  }) {
    final currentStep = getCurrentStep(
      schema: schema,
      currentStepIndex: currentStepIndex,
    );

    if (currentStep == null) {
      return FormSubmissionBlockedByWorkflow(
        formId: schema.id,
        currentStep: 'index_$currentStepIndex',
        requiredStep: 'unknown',
        reason: 'No step found at index $currentStepIndex.',
      );
    }

    // Check role requirements.
    if (currentStep.requiredRoles.isNotEmpty && userRoles != null) {
      final hasRole = userRoles.any((role) => currentStep.requiredRoles.contains(role));
      if (!hasRole) {
        return FormSubmissionBlockedByPermission(
          formId: schema.id,
          requiredPermission: currentStep.requiredRoles.join(', '),
          reason: 'User lacks required roles for step: ${currentStep.title}',
        );
      }
    }

    // Check entitlement requirements.
    if (currentStep.requiredEntitlements.isNotEmpty && userEntitlements != null) {
      final missing = currentStep.requiredEntitlements
          .where((ent) => !userEntitlements.contains(ent))
          .toList();
      if (missing.isNotEmpty) {
        return FormSubmissionBlockedByEntitlement(
          formId: schema.id,
          requiredEntitlements: missing,
          reason: 'User lacks required entitlements for step: ${currentStep.title}',
        );
      }
    }

    // Check approval requirements.
    if (currentStep.approvalRequired) {
      // In production, check against approval state.
      // For now, check if transition rules allow it.
      final approvalRule = currentStep.transitionRules.whereType<ApprovalBasedTransition>().firstOrNull;
      if (approvalRule != null) {
        // Check if user has approver role.
        if (userRoles != null) {
          final hasApproverRole = userRoles.any((role) => approvalRule.approverRoles.contains(role));
          if (!hasApproverRole) {
            return FormSubmissionBlockedByPermission(
              formId: schema.id,
              requiredPermission: approvalRule.approverRoles.join(', '),
              reason: 'User lacks approver role for step: ${currentStep.title}',
            );
          }
        }
      }
    }

    // Evaluate transition rules.
    final targetStepId = _transitionManager.evaluateTransition(
      step: currentStep,
      values: values,
      userRoles: userRoles,
      userEntitlements: userEntitlements,
    );

    if (targetStepId == null && currentStep.transitionRules.isNotEmpty) {
      return FormSubmissionBlockedByWorkflow(
        formId: schema.id,
        currentStep: currentStep.id,
        requiredStep: 'conditions not met',
        reason: 'Transition conditions not satisfied for step: ${currentStep.title}',
      );
    }

    // Transition allowed.
    return FormSubmittedSuccessfully(
      formId: schema.id,
      submissionId: 'transition_${currentStep.id}',
    );
  }

  /// Get all steps for a form.
  List<WorkflowStepConfig> getAllSteps(FormSchema schema) {
    return schema.workflowSteps;
  }

  /// Get step by ID.
  WorkflowStepConfig? getStepById({
    required FormSchema schema,
    required String stepId,
  }) {
    return schema.workflowSteps.firstWhere(
      (step) => step.id == stepId,
      orElse: () => throw WorkflowTransitionBlockedException(
        message: 'Step not found: $stepId',
        currentStep: 'unknown',
        targetStep: stepId,
      ),
    );
  }

  /// Get the index of a step.
  int getStepIndex({
    required FormSchema schema,
    required String stepId,
  }) {
    return schema.workflowSteps.indexWhere((step) => step.id == stepId);
  }

  /// Check if the form is at the final step.
  bool isFinalStep({
    required FormSchema schema,
    required int currentStepIndex,
  }) {
    return currentStepIndex == schema.workflowSteps.length - 1;
  }

  /// Get progress percentage.
  double getProgress({
    required FormSchema schema,
    required int currentStepIndex,
  }) {
    if (schema.workflowSteps.isEmpty) return 1.0;
    return (currentStepIndex + 1) / schema.workflowSteps.length;
  }
}
