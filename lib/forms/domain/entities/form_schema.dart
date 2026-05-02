import 'package:flutter_production_kit/forms/domain/entities/form_field.dart';
import 'package:flutter_production_kit/forms/domain/entities/workflow_step.dart';

/// Form schema — the complete definition of a form.
///
/// Design rationale:
/// - [id] is the stable identifier for this form type.
/// - [version] enables schema migration and draft compatibility checks.
/// - [title] is the human-readable form name.
/// - [sections] group fields logically for rendering and validation.
/// - [workflowSteps] define the multi-step progression.
/// - [submitEndpoint] is the API endpoint for submission.
/// - [submitMethod] is the HTTP method for submission.
/// - [allowOffline] determines if the form can be completed offline.
/// - [draftExpiry] defines how long drafts are kept.
/// - [requiresApproval] determines if the form needs an approval workflow.
/// - [requiredEntitlements] enforces subscription-based access.
/// - [requiredRoles] enforces role-based access.
/// - [metadata] carries safe diagnostic data — NEVER sensitive info.
///
/// Schema changes are versioned. Drafts created with older schema versions
/// are migrated to the current version before submission.
class FormSchema {
  const FormSchema({
    required this.id,
    required this.version,
    required this.title,
    required this.sections,
    this.workflowSteps = const [],
    this.submitEndpoint,
    this.submitMethod = 'POST',
    this.allowOffline = true,
    this.draftExpiry = const Duration(days: 7),
    this.requiresApproval = false,
    this.requiredEntitlements = const [],
    this.requiredRoles = const [],
    this.allowedTenants,
    this.allowedBranches,
    this.minAppVersion,
    this.metadata = const {},
  });

  final String id;
  final int version;
  final String title;
  final List<FormSection> sections;
  final List<WorkflowStepConfig> workflowSteps;
  final String? submitEndpoint;
  final String submitMethod;
  final bool allowOffline;
  final Duration draftExpiry;
  final bool requiresApproval;
  final List<String> requiredEntitlements;
  final List<String> requiredRoles;
  final List<String>? allowedTenants;
  final List<String>? allowedBranches;
  final String? minAppVersion;
  final Map<String, String> metadata;

  /// Get all fields across all sections (flat list).
  List<FormFieldConfig> get allFields {
    return sections.expand((section) => section.fields).toList();
  }

  /// Get a field by key.
  FormFieldConfig? getField(String key) {
    for (final section in sections) {
      for (final field in section.fields) {
        if (field.key == key) return field;
        if (field.isCompound) {
          final child = field.childFields?.firstWhere(
            (f) => f.key == key,
            orElse: () => throw Exception('Not found'),
          );
          if (child != null) return child;
        }
      }
    }
    return null;
  }

  /// Get dependency graph — map of field key to fields it depends on.
  Map<String, List<String>> get dependencyGraph {
    final graph = <String, List<String>>{};
    for (final field in allFields) {
      if (field.dependsOn.isNotEmpty) {
        graph[field.key] = List<String>.from(field.dependsOn);
      }
    }
    return graph;
  }

  /// Check if this schema is compatible with a draft created with an older version.
  bool isCompatibleWith(int draftSchemaVersion) {
    // Major version changes are incompatible.
    if (_majorVersion(version) != _majorVersion(draftSchemaVersion)) {
      return false;
    }
    // Minor version changes are compatible (additive changes).
    return true;
  }

  int _majorVersion(int version) => version ~/ 100;
}

/// Form section — a logical grouping of fields.
class FormSection {
  const FormSection({
    required this.id,
    required this.title,
    required this.fields,
    this.description,
    this.icon,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.condition,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String? description;
  final String? icon;
  final List<FormFieldConfig> fields;
  final bool collapsible;
  final bool initiallyExpanded;
  final FieldVisibilityCondition? condition;
  final Map<String, String> metadata;

  bool get isConditional => condition != null;
}

/// Form values — the current state of all field values.
///
/// Design rationale:
/// - Immutable snapshot of form state at a point in time.
/// - [values] maps field keys to their current values.
/// - [modifiedFields] tracks which fields have been changed.
/// - [lastModified] enables draft staleness detection.
/// - [schemaVersion] links the values to a specific schema version.
class FormValues {
  const FormValues({
    required this.schemaId,
    required this.schemaVersion,
    this.values = const {},
    this.modifiedFields = const {},
    this.lastModified,
    this.currentStep = 0,
  });

  final String schemaId;
  final int schemaVersion;
  final Map<String, dynamic> values;
  final Map<String, DateTime> modifiedFields;
  final DateTime? lastModified;
  final int currentStep;

  dynamic get(String key) => values[key];

  bool hasValue(String key) => values.containsKey(key) && values[key] != null;

  bool isModified(String key) => modifiedFields.containsKey(key);

  FormValues copyWith({
    String? schemaId,
    int? schemaVersion,
    Map<String, dynamic>? values,
    Map<String, DateTime>? modifiedFields,
    DateTime? lastModified,
    int? currentStep,
  }) {
    return FormValues(
      schemaId: schemaId ?? this.schemaId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      values: values ?? this.values,
      modifiedFields: modifiedFields ?? this.modifiedFields,
      lastModified: lastModified ?? this.lastModified,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  /// Create a new FormValues with a field value set.
  FormValues withFieldValue(String key, dynamic value) {
    final newValues = Map<String, dynamic>.from(values);
    newValues[key] = value;
    final newModified = Map<String, DateTime>.from(modifiedFields);
    newModified[key] = DateTime.now();
    return FormValues(
      schemaId: schemaId,
      schemaVersion: schemaVersion,
      values: newValues,
      modifiedFields: newModified,
      lastModified: DateTime.now(),
      currentStep: currentStep,
    );
  }

  /// Create a new FormValues with a field value removed.
  FormValues withoutField(String key) {
    final newValues = Map<String, dynamic>.from(values);
    newValues.remove(key);
    return FormValues(
      schemaId: schemaId,
      schemaVersion: schemaVersion,
      values: newValues,
      modifiedFields: modifiedFields,
      lastModified: DateTime.now(),
      currentStep: currentStep,
    );
  }

  static const FormValues empty = FormValues(
    schemaId: '',
    schemaVersion: 0,
  );
}
