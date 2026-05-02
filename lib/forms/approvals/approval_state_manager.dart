import 'package:flutter_production_kit/forms/domain/entities/approval_state.dart';

/// Approval state manager — manages approval state machine transitions.
///
/// Design rationale:
/// - Pure state machine logic — no side effects.
/// - Determines next approver role from approval chain.
/// - Validates state transitions.
/// - Tracks approval chain progression.
class ApprovalStateManager {
  const ApprovalStateManager();

  /// Check if there's a next step in the approval chain.
  bool hasNextStep(ApprovalState approval) {
    final currentStepIndex = _getCurrentStepIndex(approval);
    return currentStepIndex < approval.approvalChain.length - 1;
  }

  /// Get the next approver role.
  String? getNextApproverRole(ApprovalState approval) {
    if (!hasNextStep(approval)) return null;

    final currentStepIndex = _getCurrentStepIndex(approval);
    final nextStep = approval.approvalChain[currentStepIndex + 1];
    return nextStep.approverRole;
  }

  /// Get the current step index from audit trail.
  int _getCurrentStepIndex(ApprovalState approval) {
    // Count approved entries to determine current step.
    final approvedCount = approval.auditTrail
        .where((entry) => entry.action == ApprovalAction.approve)
        .length;

    return approvedCount.clamp(0, approval.approvalChain.length - 1);
  }

  /// Check if an approval is complete.
  bool isComplete(ApprovalState approval) {
    return approval.isComplete;
  }

  /// Check if a user can act on an approval.
  bool canAct(ApprovalState approval, String userRole) {
    return approval.canActAs(userRole);
  }

  /// Get the approval progress as a percentage.
  double getProgress(ApprovalState approval) {
    if (approval.approvalChain.isEmpty) return 1.0;

    final approvedCount = approval.auditTrail
        .where((entry) => entry.action == ApprovalAction.approve)
        .length;

    return approvedCount / approval.approvalChain.length;
  }

  /// Get the current step description.
  String getCurrentStepDescription(ApprovalState approval) {
    final index = _getCurrentStepIndex(approval);
    if (index >= approval.approvalChain.length) {
      return 'Complete';
    }
    return approval.approvalChain[index].description;
  }

  /// Validate if a transition is allowed.
  bool canTransition({
    required ApprovalState approval,
    required ApprovalAction action,
    required String userRole,
  }) {
    if (!approval.canActAs(userRole)) return false;
    if (approval.isComplete) return false;
    return true;
  }
}
