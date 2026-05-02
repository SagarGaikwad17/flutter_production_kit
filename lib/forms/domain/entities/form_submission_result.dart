/// Sealed form submission result hierarchy.
///
/// Design rationale:
/// Every form submission returns a typed result — never a simple bool.
/// This forces call sites to handle each outcome explicitly.
/// The result carries enough context for the UI to show the correct message
/// and for the engine to log the appropriate event.
sealed class FormSubmissionResult {
  const FormSubmissionResult();

  bool get isSuccess => this is FormSubmittedSuccessfully;
  bool get isFailure => this is! FormSubmittedSuccessfully;
}

/// Form submitted successfully.
final class FormSubmittedSuccessfully extends FormSubmissionResult {
  const FormSubmittedSuccessfully({
    required this.formId,
    required this.submissionId,
    this.serverResponse,
  });

  final String formId;
  final String submissionId;
  final Map<String, dynamic>? serverResponse;
}

/// Form has local validation errors.
final class FormSubmissionLocalValidationFailed extends FormSubmissionResult {
  const FormSubmissionLocalValidationFailed({
    required this.formId,
    required this.errors,
  });

  final String formId;
  final List<FieldValidationError> errors;
}

/// Form has server-side validation errors.
final class FormSubmissionServerValidationFailed extends FormSubmissionResult {
  const FormSubmissionServerValidationFailed({
    required this.formId,
    required this.errors,
    this.httpStatusCode,
    this.serverMessage,
  });

  final String formId;
  final List<ServerValidationError> errors;
  final int? httpStatusCode;
  final String? serverMessage;
}

/// Form submission blocked by workflow state.
final class FormSubmissionBlockedByWorkflow extends FormSubmissionResult {
  const FormSubmissionBlockedByWorkflow({
    required this.formId,
    required this.currentStep,
    required this.requiredStep,
    this.reason,
  });

  final String formId;
  final String currentStep;
  final String requiredStep;
  final String? reason;
}

/// Form submission blocked by permission loss.
final class FormSubmissionBlockedByPermission extends FormSubmissionResult {
  const FormSubmissionBlockedByPermission({
    required this.formId,
    required this.requiredPermission,
    this.reason,
  });

  final String formId;
  final String requiredPermission;
  final String? reason;
}

/// Form submission blocked by entitlement.
final class FormSubmissionBlockedByEntitlement extends FormSubmissionResult {
  const FormSubmissionBlockedByEntitlement({
    required this.formId,
    required this.requiredEntitlements,
    this.currentTier,
    this.reason,
  });

  final String formId;
  final List<String> requiredEntitlements;
  final String? currentTier;
  final String? reason;
}

/// Duplicate submission prevented.
final class FormSubmissionDuplicatePrevented extends FormSubmissionResult {
  const FormSubmissionDuplicatePrevented({
    required this.formId,
    this.originalSubmissionId,
    this.originalSubmittedAt,
    this.reason,
  });

  final String formId;
  final String? originalSubmissionId;
  final DateTime? originalSubmittedAt;
  final String? reason;
}

/// Stale draft requires migration before submission.
final class FormSubmissionStaleDraft extends FormSubmissionResult {
  const FormSubmissionStaleDraft({
    required this.formId,
    required this.draftSchemaVersion,
    required this.currentSchemaVersion,
    this.requiresMigration = true,
    this.reason,
  });

  final String formId;
  final int draftSchemaVersion;
  final int currentSchemaVersion;
  final bool requiresMigration;
  final String? reason;
}

/// Form submission blocked by approval requirement.
final class FormSubmissionRequiresApproval extends FormSubmissionResult {
  const FormSubmissionRequiresApproval({
    required this.formId,
    required this.approvalId,
    required this.currentApproverRole,
    this.reason,
  });

  final String formId;
  final String approvalId;
  final String currentApproverRole;
  final String? reason;
}

/// Form submission failed due to network error.
final class FormSubmissionNetworkError extends FormSubmissionResult {
  const FormSubmissionNetworkError({
    required this.formId,
    required this.error,
    this.isRetryable = true,
  });

  final String formId;
  final String error;
  final bool isRetryable;
}

/// Field validation error — local validation failure.
class FieldValidationError {
  const FieldValidationError({
    required this.fieldKey,
    required this.message,
    this.severity = ValidationSeverityEnum.error,
    this.ruleType,
  });

  final String fieldKey;
  final String message;
  final ValidationSeverityEnum severity;
  final String? ruleType;
}

/// Server validation error — backend validation failure.
class ServerValidationError {
  const ServerValidationError({
    required this.fieldKey,
    required this.message,
    this.serverCode,
  });

  final String fieldKey;
  final String message;
  final String? serverCode;
}

enum ValidationSeverityEnum { error, warning, info }
