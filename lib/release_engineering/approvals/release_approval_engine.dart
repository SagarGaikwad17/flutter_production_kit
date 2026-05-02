import 'package:flutter_production_kit/release_engineering/domain/entities/approval_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_state.dart';
import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';
import 'package:flutter_production_kit/release_engineering/domain/repositories/release_repositories.dart';

/// Release approval engine — manages release approval workflow.
///
/// Design rationale:
/// - Approvals are role-based (engineering, product, compliance, client, security).
/// - Each role must approve before release promotion.
/// - Conditional approvals allow approval with requirements.
/// - Rejections block release promotion.
/// - White-label releases require client signoff.
/// - Approval trail is immutable — approvals cannot be modified after submission.
///
/// Approval flow:
///   1. Release requires approvals based on environment and type.
///   2. Approvers submit decisions with optional justification.
///   3. Engine tracks pending, approved, and rejected roles.
///   4. All required approvals must be obtained before promotion.
///   5. Any rejection blocks promotion.
///   6. Conditional approvals must have conditions met before promotion.
class ReleaseApprovalEngine {
  const ReleaseApprovalEngine({
    required IReleaseRepository releaseRepository,
    required IApprovalRepository approvalRepository,
    this.defaultRequiredRoles = const ['engineering', 'product'],
    this.productionRequiredRoles = const ['engineering', 'product', 'compliance', 'security'],
    this.whiteLabelRequiredRoles = const ['engineering', 'product', 'client'],
  })  : _releaseRepository = releaseRepository,
        _approvalRepository = approvalRepository;

  final IReleaseRepository _releaseRepository;
  final IApprovalRepository _approvalRepository;
  final List<String> defaultRequiredRoles;
  final List<String> productionRequiredRoles;
  final List<String> whiteLabelRequiredRoles;

  /// Get required approval roles for a release.
  List<String> getRequiredRoles({
    required ReleaseEnvironment environment,
    required bool isWhiteLabel,
    required bool isHotfix,
  }) {
    if (isHotfix) {
      return ['engineering'];
    }
    if (environment == ReleaseEnvironment.production) {
      return productionRequiredRoles;
    }
    if (isWhiteLabel) {
      return whiteLabelRequiredRoles;
    }
    return defaultRequiredRoles;
  }

  /// Submit an approval decision.
  Future<ApprovalWorkflowState> submitApproval({
    required String releaseId,
    required String role,
    required ApprovalDecision decision,
    required String approverId,
    String? justification,
    List<String>? conditions,
    bool isWhiteLabelClient = false,
    String? clientId,
  }) async {
    final record = ApprovalRecord(
      id: _generateApprovalId(),
      releaseId: releaseId,
      role: role,
      decision: decision,
      approverId: approverId,
      timestamp: DateTime.now(),
      justification: justification,
      conditions: conditions,
      isWhiteLabelClient: isWhiteLabelClient,
      clientId: clientId,
    );

    await _approvalRepository.save(record);

    final requiredRoles = await _getRequiredRolesForRelease(releaseId);
    final existingRecords = await _approvalRepository.getByReleaseId(releaseId);

    final workflowState = ApprovalWorkflowState(
      releaseId: releaseId,
      requiredApprovals: requiredRoles,
      records: existingRecords,
      createdAt: DateTime.now(),
    );

    return workflowState.addRecord(record);
  }

  /// Check if a release has all required approvals.
  Future<ApprovalWorkflowState> checkApprovalStatus(String releaseId) async {
    final requiredRoles = await _getRequiredRolesForRelease(releaseId);
    final records = await _approvalRepository.getByReleaseId(releaseId);

    return ApprovalWorkflowState(
      releaseId: releaseId,
      requiredApprovals: requiredRoles,
      records: records,
      createdAt: DateTime.now(),
    );
  }

  /// Validate that a release can proceed (all approvals obtained).
  Future<ReleaseResult> validateApprovals(String releaseId) async {
    final workflowState = await checkApprovalStatus(releaseId);

    if (workflowState.isApproved) {
      await _releaseRepository.updateStatus(
        releaseId,
        ReleaseStatus.approved,
      );
      return ReleaseValidated(
        releaseId: releaseId,
        flavor: '',
        checksum: '',
      );
    }

    final rejected = workflowState.rejectedApprovals;
    if (rejected.isNotEmpty) {
      return BlockedByApprovalMissing(
        releaseId: releaseId,
        missingRoles: rejected,
        blocker: rejected.first,
      );
    }

    final pending = workflowState.pendingApprovals;
    if (pending.isNotEmpty) {
      return BlockedByApprovalMissing(
        releaseId: releaseId,
        missingRoles: pending,
      );
    }

    return BlockedByApprovalMissing(
      releaseId: releaseId,
      missingRoles: workflowState.requiredApprovals,
    );
  }

  Future<List<String>> _getRequiredRolesForRelease(String releaseId) async {
    final release = await _releaseRepository.getById(releaseId);
    if (release == null) return defaultRequiredRoles;

    return getRequiredRoles(
      environment: release.environment,
      isWhiteLabel: release.isWhiteLabel,
      isHotfix: release.isHotfix,
    );
  }

  String _generateApprovalId() {
    return 'apr_${DateTime.now().millisecondsSinceEpoch}';
  }
}
