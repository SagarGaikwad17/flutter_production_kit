import 'dart:async';

import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/draft_state.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/exceptions/form_exception.dart';
import 'package:flutter_production_kit/forms/domain/repositories/form_repositories.dart';

/// Draft manager — handles draft persistence, auto-save, and lifecycle.
///
/// Design rationale:
/// - Manages draft creation, updates, and deletion.
/// - Auto-saves on interval or on explicit trigger.
/// - Tracks dirty state to avoid unnecessary saves.
/// - Integrates with DraftRecoveryManager for app-kill recovery.
/// - Purges expired drafts on startup.
///
/// Auto-save strategy:
/// 1. Mark draft dirty on field change.
/// 2. Auto-save timer fires at configured interval.
/// 3. If dirty, save to repository and mark clean.
/// 4. On app background, force-save immediately.
class DraftManager {
  DraftManager({
    required FormDraftRepository draftRepository,
    Duration autoSaveInterval = const Duration(seconds: 30),
  })  : _draftRepository = draftRepository,
        _autoSaveInterval = autoSaveInterval;

  static const String _tag = 'DraftManager';

  final FormDraftRepository _draftRepository;
  final Duration _autoSaveInterval;

  DraftState? _activeDraft;
  Timer? _autoSaveTimer;
  bool _isSaving = false;

  /// Start managing a draft.
  Future<DraftState> startDraft({
    required String formId,
    required FormSchema schema,
    required String userId,
    FormValues? initialValues,
    Duration? expiry,
  }) async {
    final values = initialValues ?? FormValues(
      schemaId: schema.id,
      schemaVersion: schema.version,
    );

    final draft = DraftState(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      formId: formId,
      schemaVersion: schema.version,
      values: values,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      currentStep: values.currentStep,
      expiresAt: expiry != null ? DateTime.now().add(expiry) : _computeExpiry(schema),
      userId: userId,
      isDirty: false,
    );

    await _draftRepository.saveDraft(draft);
    _activeDraft = draft;
    _startAutoSave();

    AppLogger.info(_tag, 'Draft started: ${draft.id} for form $formId');
    return draft;
  }

  /// Resume an existing draft.
  Future<DraftState> resumeDraft(String draftId) async {
    final draft = await _draftRepository.getDraft(draftId);
    if (draft == null) {
      throw DraftRecoveryException(
        message: 'Draft not found: $draftId',
        draftId: draftId,
      );
    }

    if (draft.isExpired) {
      await _draftRepository.deleteDraft(draftId);
      throw DraftExpiredException(
        message: 'Draft $draftId has expired.',
        formId: draft.formId,
        draftId: draftId,
        expiredAt: draft.expiresAt,
      );
    }

    _activeDraft = draft;
    _startAutoSave();

    AppLogger.info(_tag, 'Draft resumed: $draftId');
    return draft;
  }

  /// Update draft values.
  Future<void> updateValues(FormValues newValues) async {
    final draft = _activeDraft;
    if (draft == null) {
      throw DraftSaveException(
        message: 'No active draft to update.',
      );
    }

    _activeDraft = draft.withValues(newValues);
  }

  /// Mark draft as dirty.
  void markDirty() {
    final draft = _activeDraft;
    if (draft == null) return;
    _activeDraft = draft.markDirty();
  }

  /// Force-save the current draft.
  Future<void> saveNow() async {
    final draft = _activeDraft;
    if (draft == null) return;
    if (!draft.isDirty) return;
    if (_isSaving) return;

    _isSaving = true;
    try {
      await _draftRepository.saveDraft(_activeDraft!);
      _activeDraft = _activeDraft!.markClean();
      AppLogger.debug(_tag, 'Draft saved: ${_activeDraft!.id}');
    } catch (e, st) {
      AppLogger.error(
        _tag,
        'Failed to save draft: ${_activeDraft!.id}',
        error: e,
        stackTrace: st,
      );
      throw DraftSaveException(
        message: 'Failed to save draft: ${_activeDraft!.id}',
        formId: _activeDraft!.formId,
        draftId: _activeDraft!.id,
        cause: e,
      );
    } finally {
      _isSaving = false;
    }
  }

  /// Stop managing the current draft.
  Future<void> stopDraft() async {
    await saveNow();
    _stopAutoSave();
    _activeDraft = null;
  }

  /// Delete the current draft.
  Future<void> deleteDraft() async {
    final draft = _activeDraft;
    if (draft == null) return;

    await _draftRepository.deleteDraft(draft.id);
    _stopAutoSave();
    _activeDraft = null;

    AppLogger.info(_tag, 'Draft deleted: ${draft.id}');
  }

  /// Complete the draft (submitted successfully).
  Future<void> completeDraft() async {
    final draft = _activeDraft;
    if (draft == null) return;

    await _draftRepository.deleteDraft(draft.id);
    _stopAutoSave();
    _activeDraft = null;

    AppLogger.info(_tag, 'Draft completed and removed: ${draft.id}');
  }

  /// Get all drafts for a user.
  Future<List<DraftState>> getUserDrafts(String userId) {
    return _draftRepository.getDraftsForUser(userId);
  }

  /// Purge expired drafts.
  Future<int> purgeExpiredDrafts() {
    return _draftRepository.purgeExpiredDrafts();
  }

  /// Get the current active draft.
  DraftState? get activeDraft => _activeDraft;

  DateTime? _computeExpiry(FormSchema schema) {
    if (schema.draftExpiry == Duration.zero) return null;
    return DateTime.now().add(schema.draftExpiry);
  }

  // ── Auto-save Timer ────────────────────────────────────────────────────────

  void _startAutoSave() {
    _stopAutoSave();
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (_) {
      saveNow();
    });
  }

  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }
}
