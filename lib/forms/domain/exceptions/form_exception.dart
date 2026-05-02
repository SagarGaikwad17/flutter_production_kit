/// Form exception hierarchy.
///
/// Design rationale:
/// - Each exception type maps to a specific failure mode in the form engine.
/// - [FormException] is the base for all form errors.
/// - [SchemaException] covers schema parsing and validation failures.
/// - [ValidationException] covers field validation failures.
/// - [WorkflowException] covers workflow progression failures.
/// - [DraftException] covers draft persistence and recovery failures.
/// - [ApprovalException] covers approval workflow failures.
/// - [SubmissionException] covers form submission failures.
/// - NO sensitive data in exception messages.
sealed class FormException implements Exception {
  const FormException({required this.message, this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'FormException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Schema parsing failed — malformed schema definition.
final class SchemaParseException extends FormException {
  const SchemaParseException({
    required super.message,
    super.cause,
    this.schemaId,
  });
  final String? schemaId;
}

/// Schema version incompatible — draft was created with incompatible schema.
final class SchemaVersionIncompatibleException extends FormException {
  const SchemaVersionIncompatibleException({
    required super.message,
    required this.draftVersion,
    required this.currentVersion,
    this.formId,
  });
  final int draftVersion;
  final int currentVersion;
  final String? formId;
}

/// Schema not found — requested form schema doesn't exist.
final class SchemaNotFoundException extends FormException {
  const SchemaNotFoundException({
    required super.message,
    this.formId,
    this.version,
  });
  final String? formId;
  final int? version;
}

/// Field dependency cycle detected — circular dependency in field conditions.
final class FieldDependencyCycleException extends FormException {
  const FieldDependencyCycleException({
    required super.message,
    this.fieldKeys,
  });
  final List<String>? fieldKeys;
}

/// Validation failed — field validation error.
final class ValidationException extends FormException {
  const ValidationException({
    required super.message,
    this.fieldKey,
    this.ruleType,
  });
  final String? fieldKey;
  final String? ruleType;
}

/// Server validation reconciliation failed.
final class ServerValidationReconciliationException extends FormException {
  const ServerValidationReconciliationException({
    required super.message,
    this.fieldErrors = const [],
    this.httpStatusCode,
  });
  final List<String> fieldErrors;
  final int? httpStatusCode;
}

/// Workflow transition blocked.
final class WorkflowTransitionBlockedException extends FormException {
  const WorkflowTransitionBlockedException({
    required super.message,
    this.currentStep,
    this.targetStep,
    this.reason,
  });
  final String? currentStep;
  final String? targetStep;
  final String? reason;
}

/// Permission lost during workflow.
final class WorkflowPermissionLostException extends FormException {
  const WorkflowPermissionLostException({
    required super.message,
    this.requiredPermission,
    this.currentStep,
  });
  final String? requiredPermission;
  final String? currentStep;
}

/// Draft save failed.
final class DraftSaveException extends FormException {
  const DraftSaveException({
    required super.message,
    super.cause,
    this.formId,
    this.draftId,
  });
  final String? formId;
  final String? draftId;
}

/// Draft recovery failed.
final class DraftRecoveryException extends FormException {
  const DraftRecoveryException({
    required super.message,
    super.cause,
    this.formId,
    this.draftId,
  });
  final String? formId;
  final String? draftId;
}

/// Draft expired.
final class DraftExpiredException extends FormException {
  const DraftExpiredException({
    required super.message,
    this.formId,
    this.draftId,
    this.expiredAt,
  });
  final String? formId;
  final String? draftId;
  final DateTime? expiredAt;
}

/// Approval action failed.
final class ApprovalActionFailedException extends FormException {
  const ApprovalActionFailedException({
    required super.message,
    this.approvalId,
    this.requiredRole,
    this.userRole,
  });
  final String? approvalId;
  final String? requiredRole;
  final String? userRole;
}

/// Duplicate submission detected.
final class DuplicateSubmissionException extends FormException {
  const DuplicateSubmissionException({
    required super.message,
    this.formId,
    this.originalSubmissionId,
  });
  final String? formId;
  final String? originalSubmissionId;
}

/// Offline submission not allowed.
final class OfflineSubmissionNotAllowedException extends FormException {
  const OfflineSubmissionNotAllowedException({
    required super.message,
    this.formId,
  });
  final String? formId;
}
