import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';

/// Server validation reconciler — maps backend validation errors to field-level errors.
///
/// Design rationale:
/// - Server responses may return errors in various formats.
/// - This reconciler normalizes them into FieldValidationError objects.
/// - Handles both field-specific and form-level errors.
/// - Reconciles server errors with local field definitions.
/// - Unknown fields are logged but not silently dropped.
///
/// Supported server response formats:
/// 1. Field-level: {'errors': {'field_key': 'error message'}}
/// 2. Array-level: {'errors': [{'field': 'field_key', 'message': '...'}]}
/// 3. Flat: {'error': 'form-level error message'}
class ServerValidationReconciler {
  ServerValidationReconciler({
    Map<String, String>? fieldKeyMappings,
  }) : _fieldKeyMappings = fieldKeyMappings ?? {};

  static const String _tag = 'ServerValidationReconciler';

  final Map<String, String> _fieldKeyMappings;

  /// Reconcile server response errors with form schema.
  List<ServerValidationError> reconcile({
    required FormSchema schema,
    required Map<String, dynamic> serverResponse,
    int httpStatusCode = 400,
  }) {
    final errors = <ServerValidationError>[];

    // Try field-level errors.
    final fieldErrors = _extractFieldErrors(serverResponse);
    for (final entry in fieldErrors.entries) {
      final localKey = _mapToLocalKey(entry.key);
      errors.add(ServerValidationError(
        fieldKey: localKey,
        message: entry.value,
        serverCode: _extractServerCode(serverResponse, entry.key),
      ));
    }

    // Try array-level errors.
    if (errors.isEmpty) {
      final arrayErrors = _extractArrayErrors(serverResponse);
      for (final arrayError in arrayErrors) {
        final localKey = _mapToLocalKey(arrayError['field'] as String? ?? '');
        errors.add(ServerValidationError(
          fieldKey: localKey,
          message: arrayError['message'] as String? ?? 'Unknown error',
          serverCode: arrayError['code'] as String?,
        ));
      }
    }

    // Fall back to form-level error.
    if (errors.isEmpty) {
      final formError = _extractFormError(serverResponse);
      if (formError != null) {
        errors.add(ServerValidationError(
          fieldKey: '',
          message: formError,
          serverCode: null,
        ));
      }
    }

    // Log unmapped fields.
    for (final serverKey in fieldErrors.keys) {
      if (!_hasLocalMapping(serverKey) && !schema.allFields.any((f) => f.key == serverKey)) {
        AppLogger.warning(
          _tag,
          'Server error for unknown field: $serverKey',
        );
      }
    }

    return errors;
  }

  /// Map server field keys to local field keys.
  String _mapToLocalKey(String serverKey) {
    return _fieldKeyMappings[serverKey] ?? serverKey;
  }

  bool _hasLocalMapping(String serverKey) {
    return _fieldKeyMappings.containsKey(serverKey);
  }

  Map<String, String> _extractFieldErrors(Map<String, dynamic> response) {
    final errors = <String, String>{};

    // Format: {'errors': {'field_key': 'error message'}}
    if (response['errors'] is Map<String, dynamic>) {
      final errorMap = response['errors'] as Map<String, dynamic>;
      for (final entry in errorMap.entries) {
        errors[entry.key] = entry.value.toString();
      }
    }

    // Format: {'field_errors': {'field_key': 'error message'}}
    if (response['field_errors'] is Map<String, dynamic>) {
      final errorMap = response['field_errors'] as Map<String, dynamic>;
      for (final entry in errorMap.entries) {
        errors[entry.key] = entry.value.toString();
      }
    }

    return errors;
  }

  List<Map<String, dynamic>> _extractArrayErrors(Map<String, dynamic> response) {
    final errors = <Map<String, dynamic>>[];

    // Format: {'errors': [{'field': 'key', 'message': '...'}]}
    if (response['errors'] is List) {
      final errorList = response['errors'] as List;
      for (final item in errorList) {
        if (item is Map<String, dynamic>) {
          errors.add(item);
        }
      }
    }

    // Format: {'validation_errors': [{'field': 'key', 'message': '...'}]}
    if (response['validation_errors'] is List) {
      final errorList = response['validation_errors'] as List;
      for (final item in errorList) {
        if (item is Map<String, dynamic>) {
          errors.add(item);
        }
      }
    }

    return errors;
  }

  String? _extractFormError(Map<String, dynamic> response) {
    return response['error'] as String? ??
        response['message'] as String? ??
        response['detail'] as String?;
  }

  String? _extractServerCode(Map<String, dynamic> response, String fieldKey) {
    // Try to extract server error code.
    if (response['error_codes'] is Map<String, dynamic>) {
      final codes = response['error_codes'] as Map<String, dynamic>;
      return codes[fieldKey]?.toString();
    }

    if (response['codes'] is Map<String, dynamic>) {
      final codes = response['codes'] as Map<String, dynamic>;
      return codes[fieldKey]?.toString();
    }

    return null;
  }
}
