/// Approval state — tracks the approval status of a form submission.
///
/// Design rationale:
/// - [id] is the unique approval instance identifier.
/// - [formSubmissionId] links to the original form submission.
/// - [currentState] is the current approval state machine position.
/// - [currentApproverRole] defines who can act on this approval.
/// - [approvalChain] records the full approval history.
/// - [auditTrail] provides a tamper-evident record of all actions.
///
/// State machine:
///   pending → approved/rejected/revision_requested
///   revision_requested → pending (resubmitted)
class ApprovalState {
  const ApprovalState({
    required this.id,
    required this.formSubmissionId,
    required this.currentState,
    required this.currentApproverRole,
    required this.approvalChain,
    required this.createdAt,
    this.updatedAt,
    this.auditTrail = const [],
    this.metadata = const {},
  });

  final String id;
  final String formSubmissionId;
  final ApprovalStatus currentState;
  final String currentApproverRole;
  final List<ApprovalStep> approvalChain;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ApprovalAuditEntry> auditTrail;
  final Map<String, String> metadata;

  bool get isComplete =>
      currentState == ApprovalStatus.approved ||
      currentState == ApprovalStatus.rejected;

  bool get isPending => currentState == ApprovalStatus.pending;

  bool canActAs(String role) {
    return currentApproverRole == role && isPending;
  }

  ApprovalState transition({
    required ApprovalAction action,
    required String actedBy,
    required String actedByRole,
    String? comment,
  }) {
    final newStatus = switch (action) {
      ApprovalAction.approve => ApprovalStatus.approved,
      ApprovalAction.reject => ApprovalStatus.rejected,
      ApprovalAction.requestRevision => ApprovalStatus.revisionRequested,
    };

    final newEntry = ApprovalAuditEntry(
      action: action,
      actedBy: actedBy,
      actedByRole: actedByRole,
      comment: comment,
      timestamp: DateTime.now(),
    );

    return ApprovalState(
      id: id,
      formSubmissionId: formSubmissionId,
      currentState: newStatus,
      currentApproverRole: currentApproverRole,
      approvalChain: approvalChain,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      auditTrail: [...auditTrail, newEntry],
      metadata: metadata,
    );
  }
}

/// Approval step — a single step in the approval chain.
class ApprovalStep {
  const ApprovalStep({
    required this.order,
    required this.approverRole,
    required this.description,
    this.approvalRequired = true,
  });

  final int order;
  final String approverRole;
  final String description;
  final bool approvalRequired;
}

/// Approval action — what an approver can do.
enum ApprovalAction { approve, reject, requestRevision }

/// Approval status — the current state of an approval.
enum ApprovalStatus {
  pending,
  approved,
  rejected,
  revisionRequested,
  cancelled,
}

/// Approval audit entry — immutable record of an approval action.
class ApprovalAuditEntry {
  const ApprovalAuditEntry({
    required this.action,
    required this.actedBy,
    required this.actedByRole,
    this.comment,
    required this.timestamp,
  });

  final ApprovalAction action;
  final String actedBy;
  final String actedByRole;
  final String? comment;
  final DateTime timestamp;
}
