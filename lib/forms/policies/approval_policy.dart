import 'package:flutter_production_kit/forms/domain/entities/approval_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';

/// Approval policy — determines if a form requires approval and who can approve.
///
/// Design rationale:
/// - Determines approval chain from schema configuration.
/// - Validates approver roles against user roles.
/// - Checks if submission can proceed without approval.
/// - Returns typed results for each failure mode.
class ApprovalPolicy {
  const ApprovalPolicy();

  /// Check if a form submission requires approval.
  bool requiresApproval(FormSchema schema) {
    return schema.requiresApproval ||
        schema.workflowSteps.any((step) => step.approvalRequired);
  }

  /// Get the approval chain for a form.
  List<ApprovalStep> getApprovalChain(FormSchema schema) {
    final steps = <ApprovalStep>[];
    int order = 1;

    for (final workflowStep in schema.workflowSteps) {
      if (workflowStep.approvalRequired) {
        steps.add(ApprovalStep(
          order: order++,
          approverRole: workflowStep.requiredRoles.firstOrNull ??
              workflowStep.requiredEntitlements.firstOrNull ??
              'admin',
          description: 'Approval for step: ${workflowStep.title}',
          approvalRequired: true,
        ));
      }
    }

    // If no workflow steps have approval but form requires it, add a default.
    if (steps.isEmpty && schema.requiresApproval) {
      steps.add(ApprovalStep(
        order: 1,
        approverRole: schema.requiredRoles.firstOrNull ?? 'admin',
        description: 'Approval for form: ${schema.title}',
        approvalRequired: true,
      ));
    }

    return steps;
  }

  /// Check if a user can approve based on their roles.
  FormSubmissionResult? canApprove({
    required List<String> userRoles,
    required String requiredApproverRole,
  }) {
    if (!userRoles.contains(requiredApproverRole)) {
      return FormSubmissionBlockedByPermission(
        formId: 'approval',
        requiredPermission: requiredApproverRole,
        reason: 'User role not authorized to approve.',
      );
    }
    return null;
  }

  /// Check if approval is complete.
  bool isApprovalComplete({
    required ApprovalState approval,
    required int totalSteps,
  }) {
    if (approval.currentState == ApprovalStatus.approved) {
      return true;
    }

    final approvedCount = approval.auditTrail
        .where((entry) => entry.action == ApprovalAction.approve)
        .length;

    return approvedCount >= totalSteps;
  }
}

extension _ListFirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
