import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/draft_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';
import 'package:flutter_production_kit/forms/domain/exceptions/form_exception.dart';
import 'package:flutter_production_kit/forms/domain/repositories/form_repositories.dart';

/// Draft recovery manager — handles draft recovery after app kill/crash.
///
/// Design rationale:
/// - Recovers drafts when the app restarts.
/// - Checks schema compatibility before recovery.
/// - Migrates drafts if schema version changed (minor version only).
/// - Rejects drafts with incompatible major versions.
/// - Prioritizes most recent draft per form.
///
/// Recovery flow:
/// 1. Find drafts for the user.
/// 2. Filter by form ID (if specified).
/// 3. Check expiry — reject expired drafts.
/// 4. Check schema compatibility.
/// 5. Return recovery result with actionable guidance.
class DraftRecoveryManager {
  DraftRecoveryManager({
    required FormDraftRepository draftRepository,
  }) : _draftRepository = draftRepository;

  static const String _tag = 'DraftRecoveryManager';

  final FormDraftRepository _draftRepository;

  /// Recover the most recent draft for a form.
  Future<FormSubmissionResult> recoverDraft({
    required String formId,
    required String userId,
    required FormSchema currentSchema,
  }) async {
    final drafts = await _draftRepository.getDraftsForUser(userId);
    final formDrafts = drafts.where((d) => d.formId == formId).toList();

    if (formDrafts.isEmpty) {
      return FormSubmittedSuccessfully(
        formId: formId,
        submissionId: 'no_draft',
      );
    }

    // Sort by updatedAt descending.
    formDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final latest = formDrafts.first;

    // Check expiry.
    if (latest.isExpired) {
      await _draftRepository.deleteDraft(latest.id);
      return FormSubmissionStaleDraft(
        formId: formId,
        draftSchemaVersion: latest.schemaVersion,
        currentSchemaVersion: currentSchema.version,
        requiresMigration: false,
        reason: 'Draft expired at ${latest.expiresAt}.',
      );
    }

    // Check schema compatibility.
    if (!currentSchema.isCompatibleWith(latest.schemaVersion)) {
      return FormSubmissionStaleDraft(
        formId: formId,
        draftSchemaVersion: latest.schemaVersion,
        currentSchemaVersion: currentSchema.version,
        requiresMigration: true,
        reason: 'Draft schema v${latest.schemaVersion} incompatible with current v${currentSchema.version}.',
      );
    }

    // Draft is recoverable.
    AppLogger.info(
      _tag,
      'Draft recovered: ${latest.id} for form $formId (step ${latest.currentStep})',
    );

    return FormSubmittedSuccessfully(
      formId: formId,
      submissionId: latest.id,
    );
  }

  /// Recover all recoverable drafts for a user.
  Future<List<DraftState>> recoverAllDrafts({
    required String userId,
    Map<String, FormSchema>? schemasById,
  }) async {
    final drafts = await _draftRepository.getDraftsForUser(userId);
    final recoverable = <DraftState>[];

    for (final draft in drafts) {
      // Skip expired.
      if (draft.isExpired) {
        await _draftRepository.deleteDraft(draft.id);
        continue;
      }

      // Check schema compatibility if schema is provided.
      if (schemasById != null) {
        final schema = schemasById[draft.formId];
        if (schema != null && !schema.isCompatibleWith(draft.schemaVersion)) {
          continue;
        }
      }

      recoverable.add(draft);
    }

    AppLogger.info(
      _tag,
      'Recovered ${recoverable.length} drafts for user $userId',
    );

    return recoverable;
  }

  /// Migrate a draft to the current schema version.
  ///
  /// Only works for minor version changes.
  Future<DraftState> migrateDraft({
    required DraftState draft,
    required FormSchema currentSchema,
  }) async {
    if (currentSchema.isCompatibleWith(draft.schemaVersion)) {
      // Already compatible.
      return draft;
    }

    if (_majorVersion(currentSchema.version) != _majorVersion(draft.schemaVersion)) {
      throw SchemaVersionIncompatibleException(
        message: 'Cannot migrate draft: major version change required.',
        draftVersion: draft.schemaVersion,
        currentVersion: currentSchema.version,
        formId: draft.formId,
      );
    }

    // Minor version migration — update schema version.
    final migrated = DraftState(
      id: draft.id,
      formId: draft.formId,
      schemaVersion: currentSchema.version,
      values: draft.values.copyWith(
        schemaVersion: currentSchema.version,
      ),
      createdAt: draft.createdAt,
      updatedAt: DateTime.now(),
      currentStep: draft.currentStep,
      expiresAt: draft.expiresAt,
      isDirty: true,
      userId: draft.userId,
      submissionId: draft.submissionId,
      metadata: draft.metadata,
    );

    await _draftRepository.saveDraft(migrated);

    AppLogger.info(
      _tag,
      'Draft migrated: ${draft.id} from v${draft.schemaVersion} to v${currentSchema.version}',
    );

    return migrated;
  }

  int _majorVersion(int version) => version ~/ 100;
}
