/// Form field data types — the fundamental types a form field can hold.
enum FormFieldType {
  text,
  number,
  email,
  phone,
  date,
  dateTime,
  boolean,
  dropdown,
  multiSelect,
  fileUpload,
  textArea,
  currency,
  percentage,
  url,
  signature,
  nestedGroup,
  repeatableSection,
  hidden,
}

/// Form field configuration — defines a single field in a form schema.
///
/// Design rationale:
/// - [key] is the stable identifier — used in form values and validation.
/// - [type] determines the field widget and validation behavior.
/// - [label] is the human-readable display name.
/// - [required] controls validation — required fields must have a value.
/// - [visibleCondition] controls dynamic visibility based on other field values.
/// - [validationRules] are evaluated in order — first failure stops.
/// - [dependsOn] lists field keys this field depends on for visibility/validation.
/// - [defaultValue] is applied when the form is first opened.
/// - [metadata] carries safe diagnostic data — NEVER sensitive info.
class FormFieldConfig {
  const FormFieldConfig({
    required this.key,
    required this.type,
    required this.label,
    this.hint,
    this.placeholder,
    this.required = false,
    this.readOnly = false,
    this.disabled = false,
    this.visibleCondition,
    this.validationRules = const [],
    this.dependsOn = const [],
    this.defaultValue,
    this.options,
    this.maxLength,
    this.minLength,
    this.minValue,
    this.maxValue,
    this.pattern,
    this.allowedFileTypes,
    this.maxFileSizeBytes,
    this.maxFileCount,
    this.childFields,
    this.metadata = const {},
  });

  final String key;
  final FormFieldType type;
  final String label;
  final String? hint;
  final String? placeholder;
  final bool required;
  final bool readOnly;
  final bool disabled;
  final FieldVisibilityCondition? visibleCondition;
  final List<ValidationRuleConfig> validationRules;
  final List<String> dependsOn;
  final dynamic defaultValue;
  final List<FieldOption>? options;
  final int? maxLength;
  final int? minLength;
  final num? minValue;
  final num? maxValue;
  final String? pattern;
  final List<String>? allowedFileTypes;
  final int? maxFileSizeBytes;
  final int? maxFileCount;
  final List<FormFieldConfig>? childFields;
  final Map<String, String> metadata;

  bool get isCompound => childFields != null && childFields!.isNotEmpty;
  bool get isConditional => visibleCondition != null;
}

/// Field option — for dropdown, multi-select fields.
class FieldOption {
  const FieldOption({
    required this.value,
    required this.label,
    this.disabled = false,
    this.metadata = const {},
  });

  final String value;
  final String label;
  final bool disabled;
  final Map<String, String> metadata;
}

/// Field visibility condition — controls dynamic field visibility.
///
/// Conditions are evaluated against current form values.
/// Supports: equals, notEquals, contains, isEmpty, isNotEmpty, custom.
sealed class FieldVisibilityCondition {
  const FieldVisibilityCondition({required this.dependentFieldKey});
  final String dependentFieldKey;
}

final class EqualsCondition extends FieldVisibilityCondition {
  const EqualsCondition({
    required super.dependentFieldKey,
    required this.value,
  });
  final dynamic value;
}

final class NotEqualsCondition extends FieldVisibilityCondition {
  const NotEqualsCondition({
    required super.dependentFieldKey,
    required this.value,
  });
  final dynamic value;
}

final class ContainsCondition extends FieldVisibilityCondition {
  const ContainsCondition({
    required super.dependentFieldKey,
    required this.value,
  });
  final dynamic value;
}

final class IsEmptyCondition extends FieldVisibilityCondition {
  const IsEmptyCondition({required super.dependentFieldKey});
}

final class IsNotEmptyCondition extends FieldVisibilityCondition {
  const IsNotEmptyCondition({required super.dependentFieldKey});
}

final class CustomVisibilityCondition extends FieldVisibilityCondition {
  const CustomVisibilityCondition({
    required super.dependentFieldKey,
    required this.evaluatorKey,
    this.parameters = const {},
  });
  final String evaluatorKey;
  final Map<String, String> parameters;
}

/// Validation rule configuration — defines a single validation rule.
class ValidationRuleConfig {
  const ValidationRuleConfig({
    required this.type,
    required this.message,
    this.parameters = const {},
    this.severity = ValidationSeverity.error,
    this.condition,
  });

  final ValidationRuleType type;
  final String message;
  final Map<String, dynamic> parameters;
  final ValidationSeverity severity;
  final FieldVisibilityCondition? condition;
}

enum ValidationRuleType {
  required,
  minLength,
  maxLength,
  min,
  max,
  pattern,
  email,
  phone,
  url,
  date,
  fileRequired,
  fileType,
  fileSize,
  fileCount,
  custom,
}

enum ValidationSeverity {
  error,
  warning,
  info,
}
