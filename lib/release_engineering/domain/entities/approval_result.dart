/// Approval result — outcome of a release approval workflow.
///
/// Design rationale:
/// - Immutable approval record.
/// - Tracks approver, role, decision, and timestamp.
/// - Supports justification for rejection.
/// - Supports conditional approval with requirements.
/// - Audit trail for compliance.
class ApprovalRecord {
  const ApprovalRecord({
    required this.id,
    required this.releaseId,
    required this.role,
    required this.decision,
    required this.approverId,
    required this.timestamp,
    this.justification,
    this.conditions,
    this.isWhiteLabelClient = false,
    this.clientId,
  });

  final String id;
  final String releaseId;
  final String role;
  final ApprovalDecision decision;
  final String approverId;
  final DateTime timestamp;
  final String? justification;
  final List<String>? conditions;
  final bool isWhiteLabelClient;
  final String? clientId;

  bool get isApproved => decision == ApprovalDecision.approved;
  bool get isRejected => decision == ApprovalDecision.rejected;
  bool get isConditional => decision == ApprovalDecision.approvedWithConditions;
}

enum ApprovalDecision {
  approved,
  approvedWithConditions,
  rejected,
}

/// Approval workflow state — tracks all approvals for a release.
class ApprovalWorkflowState {
  const ApprovalWorkflowState({
    required this.releaseId,
    required this.requiredApprovals,
    required this.records,
    this.isComplete = false,
    this.isApproved = false,
    this.createdAt,
  });

  final String releaseId;
  final List<String> requiredApprovals;
  final List<ApprovalRecord> records;
  final bool isComplete;
  final bool isApproved;
  final DateTime? createdAt;

  List<String> get pendingApprovals {
    final approvedRoles =
        records.where((r) => r.isApproved).map((r) => r.role).toSet();
    return requiredApprovals.where((r) => !approvedRoles.contains(r)).toList();
  }

  List<String> get rejectedApprovals {
    return records
        .where((r) => r.isRejected)
        .map((r) => r.role)
        .toList();
  }

  bool hasApproval(String role) {
    return records.any((r) => r.role == role && r.isApproved);
  }

  bool hasRejection(String role) {
    return records.any((r) => r.role == role && r.isRejected);
  }

  ApprovalWorkflowState addRecord(ApprovalRecord record) {
    final updatedRecords = [
      ...records.where((r) => r.role != record.role),
      record,
    ];

    final allApproved = requiredApprovals
        .every((role) => updatedRecords.any((r) => r.role == role && r.isApproved));

    final anyRejected =
        updatedRecords.any((r) => r.isRejected);

    return ApprovalWorkflowState(
      releaseId: releaseId,
      requiredApprovals: requiredApprovals,
      records: updatedRecords,
      isComplete: allApproved || anyRejected,
      isApproved: allApproved && !anyRejected,
      createdAt: createdAt,
    );
  }
}
