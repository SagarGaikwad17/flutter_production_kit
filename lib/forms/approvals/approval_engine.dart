import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/approval_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';
import 'package:flutter_production_kit/forms/domain/exceptions/form_exception.dart';
import 'package:flutter_production_kit/forms/domain/repositories/form_repositories.dart';
import 'package:flutter_production_kit/forms/approvals/approval_state_manager.dart';

/// Approval engine — manages approval workflows for form submissions.
///
/// Design rationale:
/// - Creates approval instances for form submissions that require approval.
/// - Manages the approval state machine (pending → approved/rejected/revision_requested).
/// - Enforces role-based approval access.
/// - Maintains audit trail for compliance.
/// - Supports multi-step approval chains.
///
/// Approval flow:
/// 1. Create approval instance for submission.
/// 2. Set initial approver role from approval chain.
/// 3. Approver acts (approve/reject/request revision).
/// 4. If approved and more steps exist, advance to next approver.
/// 5. If approved and last step, mark as fully approved.
/// 6. If rejected, mark as rejected.
/// 7. If revision requested, return to submitter.
class ApprovalEngine {
  ApprovalEngine({
    required ApprovalRepository approvalRepository,
    ApprovalStateManager? stateManager,
  })  : _approvalRepository = approvalRepository,
        _stateManager = stateManager ?? const ApprovalStateManager();

  static const String _tag = 'ApprovalEngine';

  final ApprovalRepository _approvalRepository;
  final ApprovalStateManager _stateManager;

  /// Create an approval instance for a form submission.
  Future<ApprovalState> createApproval({
    required String submissionId,
    required List<ApprovalStep> approvalChain,
    required String currentApproverRole,
    Map<String, String>? metadata,
  }) async {
    if (approvalChain.isEmpty) {
      throw ApprovalActionFailedException(
        message: 'Cannot create approval with empty chain.',
        approvalId: 'unknown',
      );
    }

    final approval = ApprovalState(
      id: 'approval_${DateTime.now().millisecondsSinceEpoch}',
      formSubmissionId: submissionId,
      currentState: ApprovalStatus.pending,
      currentApproverRole: currentApproverRole,
      approvalChain: approvalChain,
      createdAt: DateTime.now(),
      auditTrail: [],
      metadata: metadata ?? {},
    );

    await _approvalRepository.saveApproval(approval);

    AppLogger.info(
      _tag,
      'Approval created: ${approval.id} for submission $submissionId '
      '(approver role: $currentApproverRole)',
    );

    return approval;
  }

  /// Get an approval by ID.
  Future<ApprovalState?> getApproval(String approvalId) {
    return _approvalRepository.getApproval(approvalId);
  }

  /// Get approvals for a submission.
  Future<List<ApprovalState>> getApprovalsForSubmission(String submissionId) {
    return _approvalRepository.getApprovalsForSubmission(submissionId);
  }

  /// Approve an approval instance.
  Future<FormSubmissionResult> approve({
    required String approvalId,
    required String actedBy,
    required String actedByRole,
    String? comment,
  }) async {
    final approval = await _approvalRepository.getApproval(approvalId);
    if (approval == null) {
      throw ApprovalActionFailedException(
        message: 'Approval not found: $approvalId',
        approvalId: approvalId,
      );
    }

    if (!approval.canActAs(actedByRole)) {
      return FormSubmissionBlockedByPermission(
        formId: approval.formSubmissionId,
        requiredPermission: approval.currentApproverRole,
        reason: 'User role $actedByRole cannot act on this approval.',
      );
    }

    final updated = approval.transition(
      action: ApprovalAction.approve,
      actedBy: actedBy,
      actedByRole: actedByRole,
      comment: comment,
    );

    // Check if there's a next step in the chain.
    final hasNext = _stateManager.hasNextStep(approval);
    if (hasNext) {
      final nextRole = _stateManager.getNextApproverRole(approval);
      final finalApproval = ApprovalState(
        id: updated.id,
        formSubmissionId: updated.formSubmissionId,
        currentState: ApprovalStatus.pending,
        currentApproverRole: nextRole ?? updated.currentApproverRole,
        approvalChain: updated.approvalChain,
        createdAt: updated.createdAt,
        updatedAt: updated.updatedAt,
        auditTrail: updated.auditTrail,
        metadata: updated.metadata,
      );
      await _approvalRepository.updateApproval(finalApproval);
      return FormSubmittedSuccessfully(
        formId: approval.formSubmissionId,
        submissionId: approvalId,
        serverResponse: {
          'status': 'pending_next_approver',
          'next_approver_role': nextRole,
        },
      );
    }

    // Last step — fully approved.
    await _approvalRepository.updateApproval(updated);
    return FormSubmittedSuccessfully(
      formId: approval.formSubmissionId,
      submissionId: approvalId,
      serverResponse: {'status': 'fully_approved'},
    );
  }

  /// Reject an approval instance.
  Future<FormSubmissionResult> reject({
    required String approvalId,
    required String actedBy,
    required String actedByRole,
    String? comment,
  }) async {
    final approval = await _approvalRepository.getApproval(approvalId);
    if (approval == null) {
      throw ApprovalActionFailedException(
        message: 'Approval not found: $approvalId',
        approvalId: approvalId,
      );
    }

    if (!approval.canActAs(actedByRole)) {
      return FormSubmissionBlockedByPermission(
        formId: approval.formSubmissionId,
        requiredPermission: approval.currentApproverRole,
        reason: 'User role $actedByRole cannot act on this approval.',
      );
    }

    final updated = approval.transition(
      action: ApprovalAction.reject,
      actedBy: actedBy,
      actedByRole: actedByRole,
      comment: comment,
    );

    await _approvalRepository.updateApproval(updated);

    return FormSubmissionBlockedByWorkflow(
      formId: approval.formSubmissionId,
      currentStep: 'approval',
      requiredStep: 'approved',
      reason: 'Approval rejected: ${comment ?? "no reason provided"}',
    );
  }

  /// Request a revision.
  Future<FormSubmissionResult> requestRevision({
    required String approvalId,
    required String actedBy,
    required String actedByRole,
    String? comment,
  }) async {
    final approval = await _approvalRepository.getApproval(approvalId);
    if (approval == null) {
      throw ApprovalActionFailedException(
        message: 'Approval not found: $approvalId',
        approvalId: approvalId,
      );
    }

    if (!approval.canActAs(actedByRole)) {
      return FormSubmissionBlockedByPermission(
        formId: approval.formSubmissionId,
        requiredPermission: approval.currentApproverRole,
        reason: 'User role $actedByRole cannot act on this approval.',
      );
    }

    final updated = approval.transition(
      action: ApprovalAction.requestRevision,
      actedBy: actedBy,
      actedByRole: actedByRole,
      comment: comment,
    );

    await _approvalRepository.updateApproval(updated);

    return FormSubmissionBlockedByWorkflow(
      formId: approval.formSubmissionId,
      currentStep: 'approval',
      requiredStep: 'resubmit',
      reason: 'Revision requested: ${comment ?? "no reason provided"}',
    );
  }

  /// Get pending approvals for a user.
  Future<List<ApprovalState>> getPendingApprovalsForUser(
    String userId,
    List<String> userRoles,
  ) {
    return _approvalRepository.getPendingApprovalsForUser(userId, userRoles);
  }

  /// Get pending approvals for a role.
  Future<List<ApprovalState>> getPendingApprovalsForRole(String role) {
    return _approvalRepository.getPendingApprovalsForRole(role);
  }
}
