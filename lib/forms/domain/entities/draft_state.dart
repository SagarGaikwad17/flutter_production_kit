import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';

/// Draft state — persisted form data for recovery.
///
/// Design rationale:
/// - [id] is the unique draft identifier.
/// - [formId] links to the form schema.
/// - [schemaVersion] enables compatibility checks with current schema.
/// - [values] contains the saved field values.
/// - [currentStep] tracks the user's progress in multi-step forms.
/// - [createdAt] and [updatedAt] enable staleness detection.
/// - [expiresAt] determines when the draft should be purged.
/// - [isDirty] tracks if the draft has unsaved changes.
/// - [userId] links the draft to a specific user.
///
/// Drafts are auto-saved on field changes and on app background.
/// Drafts are purged after [expiresAt] or after successful submission.
class DraftState {
  const DraftState({
    required this.id,
    required this.formId,
    required this.schemaVersion,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
    this.currentStep = 0,
    this.expiresAt,
    this.isDirty = false,
    this.userId,
    this.submissionId,
    this.metadata = const {},
  });

  final String id;
  final String formId;
  final int schemaVersion;
  final FormValues values;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int currentStep;
  final DateTime? expiresAt;
  final bool isDirty;
  final String? userId;
  final String? submissionId;
  final Map<String, String> metadata;

  bool get isExpired {
    final expires = expiresAt;
    if (expires == null) return false;
    return DateTime.now().isAfter(expires);
  }

  bool get isSchemaCompatible {
    // Drafts are compatible if schema major version matches.
    return _majorVersion(schemaVersion) == _majorVersion(schemaVersion);
  }

  int _majorVersion(int version) => version ~/ 100;

  DraftState markDirty() {
    return DraftState(
      id: id,
      formId: formId,
      schemaVersion: schemaVersion,
      values: values,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      currentStep: currentStep,
      expiresAt: expiresAt,
      isDirty: true,
      userId: userId,
      submissionId: submissionId,
      metadata: metadata,
    );
  }

  DraftState markClean() {
    return DraftState(
      id: id,
      formId: formId,
      schemaVersion: schemaVersion,
      values: values,
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentStep: currentStep,
      expiresAt: expiresAt,
      isDirty: false,
      userId: userId,
      submissionId: submissionId,
      metadata: metadata,
    );
  }

  DraftState withValues(FormValues newValues) {
    return DraftState(
      id: id,
      formId: formId,
      schemaVersion: schemaVersion,
      values: newValues,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      currentStep: newValues.currentStep,
      expiresAt: expiresAt,
      isDirty: true,
      userId: userId,
      submissionId: submissionId,
      metadata: metadata,
    );
  }
}
