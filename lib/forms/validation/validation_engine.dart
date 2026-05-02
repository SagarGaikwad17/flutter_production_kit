import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_field.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';
import 'package:flutter_production_kit/forms/domain/entities/workflow_step.dart';

/// Validation engine — evaluates field validation rules against form values.
///
/// Design rationale:
/// - Validates fields based on their type, rules, and schema constraints.
/// - Only validates visible fields (conditional fields are skipped when hidden).
/// - Validation modes: onExit (step exit), onSubmit (final submit), lazy (on change).
/// - Returns typed FieldValidationError with severity.
/// - Custom validators can be registered for domain-specific rules.
///
/// Validation order:
/// 1. Required check — field must have a value if required.
/// 2. Type validation — value must match the field's declared type.
/// 3. Constraint validation — minLength, maxLength, min, max, pattern.
/// 4. Custom validation — registered custom validators.
class ValidationEngine {
  ValidationEngine({
    Map<String, CustomValidator>? customValidators,
  }) : _customValidators = customValidators ?? {};

  static const String _tag = 'ValidationEngine';

  final Map<String, CustomValidator> _customValidators;

  /// Validate all fields in the schema against current values.
  List<FieldValidationError> validate({
    required FormSchema schema,
    required FormValues values,
    Set<String>? visibleFields,
    StepValidationMode mode = StepValidationMode.onExit,
  }) {
    final errors = <FieldValidationError>[];
    final fieldsToValidate = _resolveFieldsToValidate(
      schema: schema,
      visibleFields: visibleFields,
      mode: mode,
    );

    for (final field in fieldsToValidate) {
      final fieldErrors = _validateField(field, values);
      errors.addAll(fieldErrors);
    }

    return errors;
  }

  /// Validate a single field.
  List<FieldValidationError> validateField({
    required FormFieldConfig field,
    required FormValues values,
  }) {
    return _validateField(field, values);
  }

  /// Check if a field value is valid.
  bool isFieldValid({
    required FormFieldConfig field,
    required FormValues values,
  }) {
    return _validateField(field, values).isEmpty;
  }

  // ── Internal Validation ────────────────────────────────────────────────────

  List<FormFieldConfig> _resolveFieldsToValidate({
    required FormSchema schema,
    Set<String>? visibleFields,
    StepValidationMode mode = StepValidationMode.onExit,
  }) {
    return switch (mode) {
      StepValidationMode.onExit ||
      StepValidationMode.onSubmit =>
        visibleFields != null
            ? schema.allFields
                .where((f) => visibleFields.contains(f.key))
                .toList()
            : schema.allFields,
      StepValidationMode.lazy => const [],
      StepValidationMode.none => const [],
    };
  }

  List<FieldValidationError> _validateField(
    FormFieldConfig field,
    FormValues values,
  ) {
    final errors = <FieldValidationError>[];
    final fieldValue = values.get(field.key);

    // Required check.
    if (field.required && _isEmpty(fieldValue)) {
      errors.add(FieldValidationError(
        fieldKey: field.key,
        message: '${field.label} is required.',
        severity: ValidationSeverityEnum.error,
        ruleType: ValidationRuleType.required.name,
      ));
      return errors; // Early return — no point checking other rules.
    }

    if (_isEmpty(fieldValue)) {
      return errors; // Optional field with no value — skip further checks.
    }

    // Type validation.
    final typeError = _validateType(field, fieldValue);
    if (typeError != null) {
      errors.add(typeError);
      return errors;
    }

    // Rule validation.
    for (final rule in field.validationRules) {
      final ruleError = _validateRule(field, rule, fieldValue);
      if (ruleError != null) {
        errors.add(ruleError);
        if (rule.severity == ValidationSeverity.error) {
          break; // Stop on first error; warnings continue.
        }
      }
    }

    // Field-level constraint validation.
    final constraintErrors = _validateConstraints(field, fieldValue);
    errors.addAll(constraintErrors);

    // Custom validation.
    for (final rule in field.validationRules) {
      if (rule.type == ValidationRuleType.custom) {
        final validatorKey = rule.parameters['validatorKey'] as String?;
        if (validatorKey != null) {
          final customError = _validateCustom(
            validatorKey,
            field,
            fieldValue,
            rule,
          );
          if (customError != null) {
            errors.add(customError);
          }
        }
      }
    }

    return errors;
  }

  FieldValidationError? _validateType(
    FormFieldConfig field,
    dynamic value,
  ) {
    final valid = switch (field.type) {
      FormFieldType.text ||
      FormFieldType.textArea ||
      FormFieldType.email ||
      FormFieldType.phone ||
      FormFieldType.url ||
      FormFieldType.currency ||
      FormFieldType.percentage =>
        value is String,
      FormFieldType.number => value is num,
      FormFieldType.date || FormFieldType.dateTime => value is DateTime,
      FormFieldType.boolean => value is bool,
      FormFieldType.dropdown ||
      FormFieldType.multiSelect =>
        value is String || value is List<String>,
      FormFieldType.fileUpload => value is List<Map<String, dynamic>>,
      FormFieldType.signature => value is String || value is List<int>,
      FormFieldType.nestedGroup || FormFieldType.repeatableSection =>
        value is Map<String, dynamic> || value is List,
      FormFieldType.hidden => true,
    };

    if (!valid) {
      return FieldValidationError(
        fieldKey: field.key,
        message: '${field.label} has an invalid type.',
        severity: ValidationSeverityEnum.error,
        ruleType: 'type',
      );
    }

    return null;
  }

  FieldValidationError? _validateRule(
    FormFieldConfig field,
    ValidationRuleConfig rule,
    dynamic value,
  ) {
    // Check rule condition.
    if (rule.condition != null) {
      // Evaluate condition against values — simplified for now.
    }

    return switch (rule.type) {
      ValidationRuleType.required =>
        _isEmpty(value)
            ? FieldValidationError(
                fieldKey: field.key,
                message: rule.message,
                severity: _toSeverityEnum(rule.severity),
                ruleType: rule.type.name,
              )
            : null,
      ValidationRuleType.email => _validateEmail(field, value, rule),
      ValidationRuleType.phone => _validatePhone(field, value, rule),
      ValidationRuleType.url => _validateUrl(field, value, rule),
      ValidationRuleType.pattern => _validatePattern(field, value, rule),
      _ => null,
    };
  }

  List<FieldValidationError> _validateConstraints(
    FormFieldConfig field,
    dynamic value,
  ) {
    final errors = <FieldValidationError>[];

    if (value is String) {
      if (field.minLength != null && value.length < field.minLength!) {
        errors.add(FieldValidationError(
          fieldKey: field.key,
          message: 'Must be at least ${field.minLength} characters.',
          severity: ValidationSeverityEnum.error,
          ruleType: ValidationRuleType.minLength.name,
        ));
      }
      if (field.maxLength != null && value.length > field.maxLength!) {
        errors.add(FieldValidationError(
          fieldKey: field.key,
          message: 'Must be at most ${field.maxLength} characters.',
          severity: ValidationSeverityEnum.error,
          ruleType: ValidationRuleType.maxLength.name,
        ));
      }
    }

    if (value is num) {
      if (field.minValue != null && value < field.minValue!) {
        errors.add(FieldValidationError(
          fieldKey: field.key,
          message: 'Must be at least ${field.minValue}.',
          severity: ValidationSeverityEnum.error,
          ruleType: ValidationRuleType.min.name,
        ));
      }
      if (field.maxValue != null && value > field.maxValue!) {
        errors.add(FieldValidationError(
          fieldKey: field.key,
          message: 'Must be at most ${field.maxValue}.',
          severity: ValidationSeverityEnum.error,
          ruleType: ValidationRuleType.max.name,
        ));
      }
    }

    return errors;
  }

  FieldValidationError? _validateEmail(
    FormFieldConfig field,
    dynamic value,
    ValidationRuleConfig rule,
  ) {
    if (value is! String) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return FieldValidationError(
        fieldKey: field.key,
        message: rule.message,
        severity: _toSeverityEnum(rule.severity),
        ruleType: rule.type.name,
      );
    }
    return null;
  }

  FieldValidationError? _validatePhone(
    FormFieldConfig field,
    dynamic value,
    ValidationRuleConfig rule,
  ) {
    if (value is! String) return null;
    final phoneRegex = RegExp(r'^\+?[\d\s\-()]{7,20}$');
    if (!phoneRegex.hasMatch(value)) {
      return FieldValidationError(
        fieldKey: field.key,
        message: rule.message,
        severity: _toSeverityEnum(rule.severity),
        ruleType: rule.type.name,
      );
    }
    return null;
  }

  FieldValidationError? _validateUrl(
    FormFieldConfig field,
    dynamic value,
    ValidationRuleConfig rule,
  ) {
    if (value is! String) return null;
    try {
      Uri.parse(value);
    } catch (_) {
      return FieldValidationError(
        fieldKey: field.key,
        message: rule.message,
        severity: _toSeverityEnum(rule.severity),
        ruleType: rule.type.name,
      );
    }
    return null;
  }

  FieldValidationError? _validatePattern(
    FormFieldConfig field,
    dynamic value,
    ValidationRuleConfig rule,
  ) {
    if (value is! String) return null;
    final patternStr = rule.parameters['pattern'] as String? ?? field.pattern;
    if (patternStr == null) return null;

    final regex = RegExp(patternStr);
    if (!regex.hasMatch(value)) {
      return FieldValidationError(
        fieldKey: field.key,
        message: rule.message,
        severity: _toSeverityEnum(rule.severity),
        ruleType: rule.type.name,
      );
    }
    return null;
  }

  FieldValidationError? _validateCustom(
    String validatorKey,
    FormFieldConfig field,
    dynamic value,
    ValidationRuleConfig rule,
  ) {
    final validator = _customValidators[validatorKey];
    if (validator == null) {
      AppLogger.warning(
        _tag,
        'Custom validator "$validatorKey" not found for field ${field.key}.',
      );
      return null;
    }

    final result = validator.validate(value, rule.parameters);
    if (!result.isValid) {
      return FieldValidationError(
        fieldKey: field.key,
        message: result.errorMessage ?? rule.message,
        severity: _toSeverityEnum(rule.severity),
        ruleType: rule.type.name,
      );
    }
    return null;
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String && value.isEmpty) return true;
    if (value is Iterable && value.isEmpty) return true;
    if (value is Map && value.isEmpty) return true;
    return false;
  }

  ValidationSeverityEnum _toSeverityEnum(ValidationSeverity severity) {
    return switch (severity) {
      ValidationSeverity.error => ValidationSeverityEnum.error,
      ValidationSeverity.warning => ValidationSeverityEnum.warning,
      ValidationSeverity.info => ValidationSeverityEnum.info,
    };
  }
}

/// Custom validator — for domain-specific validation rules.
abstract class CustomValidator {
  const CustomValidator();
  ValidationResult validate(dynamic value, Map<String, dynamic> parameters);
}

/// Result of a custom validation.
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  final bool isValid;
  final String? errorMessage;

  static const ValidationResult valid = ValidationResult(isValid: true);

  static ValidationResult invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}
