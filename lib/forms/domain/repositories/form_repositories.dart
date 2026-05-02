import 'package:flutter_production_kit/forms/domain/entities/approval_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/draft_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';

/// Abstract repository for form schemas.
abstract class FormSchemaRepository {
  const FormSchemaRepository();

  /// Get a form schema by ID and version.
  Future<FormSchema?> getSchema(String formId, {int? version});

  /// Get the latest version of a form schema.
  Future<FormSchema?> getLatestSchema(String formId);

  /// Get all available form schemas.
  Future<List<FormSchema>> getAllSchemas();

  /// Check if a schema exists.
  Future<bool> hasSchema(String formId);

  /// Cache a schema locally.
  Future<void> cacheSchema(FormSchema schema);
}

/// Abstract repository for form drafts.
abstract class FormDraftRepository {
  const FormDraftRepository();

  /// Save a draft.
  Future<void> saveDraft(DraftState draft);

  /// Get a draft by ID.
  Future<DraftState?> getDraft(String draftId);

  /// Get all drafts for a form.
  Future<List<DraftState>> getDraftsForForm(String formId);

  /// Get all drafts for a user.
  Future<List<DraftState>> getDraftsForUser(String userId);

  /// Delete a draft.
  Future<void> deleteDraft(String draftId);

  /// Delete all expired drafts.
  Future<int> purgeExpiredDrafts();

  /// Check if a draft exists.
  Future<bool> hasDraft(String draftId);
}

/// Abstract repository for approval states.
abstract class ApprovalRepository {
  const ApprovalRepository();

  /// Save an approval state.
  Future<void> saveApproval(ApprovalState approval);

  /// Get an approval state by ID.
  Future<ApprovalState?> getApproval(String approvalId);

  /// Get approvals for a form submission.
  Future<List<ApprovalState>> getApprovalsForSubmission(String submissionId);

  /// Get approvals pending for a role.
  Future<List<ApprovalState>> getPendingApprovalsForRole(String role);

  /// Get approvals pending for a user.
  Future<List<ApprovalState>> getPendingApprovalsForUser(
    String userId,
    List<String> userRoles,
  );

  /// Update an approval state.
  Future<void> updateApproval(ApprovalState approval);
}
