import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_field.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/exceptions/form_exception.dart';

/// Field dependency engine — manages conditional field visibility and dependencies.
///
/// Design rationale:
/// - Evaluates field visibility conditions against current form values.
/// - Detects circular dependencies in field conditions.
/// - Recalculates visibility when dependent fields change.
/// - Returns only the fields that should be visible to the user.
/// - Handles nested and compound fields (nested groups, repeatable sections).
///
/// Dependency resolution:
/// 1. Build dependency graph from all fields.
/// 2. Detect cycles — throw FieldDependencyCycleException if found.
/// 3. Evaluate conditions in topological order.
/// 4. Return set of visible field keys.
class FieldDependencyEngine {
  FieldDependencyEngine({
    Map<String, CustomVisibilityEvaluator>? customEvaluators,
  }) : _customEvaluators = customEvaluators ?? {};

  static const String _tag = 'FieldDependencyEngine';

  final Map<String, CustomVisibilityEvaluator> _customEvaluators;

  /// Get the set of visible field keys based on current form values.
  Set<String> getVisibleFields({
    required FormSchema schema,
    required FormValues values,
  }) {
    final graph = schema.dependencyGraph;
    if (graph.isEmpty) {
      // No dependencies — all fields are visible.
      return schema.allFields.map((f) => f.key).toSet();
    }

    // Detect cycles.
    _detectCycles(graph);

    // Evaluate visibility in topological order.
    final visible = <String>{};
    final evaluated = <String>{};

    for (final field in schema.allFields) {
      if (_isFieldVisible(field, values, evaluated, visible)) {
        visible.add(field.key);
      }
      evaluated.add(field.key);
    }

    return visible;
  }

  /// Get the fields that changed visibility due to a field value change.
  Set<String> getAffectedFields({
    required FormSchema schema,
    required String changedFieldKey,
    required FormValues oldValues,
    required FormValues newValues,
  }) {
    final affected = <String>{};

    for (final field in schema.allFields) {
      if (field.dependsOn.contains(changedFieldKey)) {
        final wasVisible = _evaluateCondition(
          field.visibleCondition,
          oldValues,
        );
        final isVisible = _evaluateCondition(
          field.visibleCondition,
          newValues,
        );

        if (wasVisible != isVisible) {
          affected.add(field.key);
        }
      }
    }

    return affected;
  }

  /// Check if a field should be visible.
  bool isFieldVisible({
    required FormFieldConfig field,
    required FormValues values,
  }) {
    return _evaluateCondition(field.visibleCondition, values);
  }

  // ── Internal Evaluation ────────────────────────────────────────────────────

  bool _isFieldVisible(
    FormFieldConfig field,
    FormValues values,
    Set<String> evaluated,
    Set<String> visible,
  ) {
    if (field.dependsOn.isEmpty) {
      return true;
    }

    // Check if all dependencies are evaluated.
    for (final depKey in field.dependsOn) {
      if (!evaluated.contains(depKey)) {
        // Find and evaluate the dependency first.
        final depField = _findField(visible, field, depKey);
        if (depField != null) {
          _isFieldVisible(depField, values, evaluated, visible);
        }
      }
    }

    return _evaluateCondition(field.visibleCondition, values);
  }

  FormFieldConfig? _findField(
    Set<String> visible,
    FormFieldConfig currentField,
    String depKey,
  ) {
    if (currentField.key == depKey) return currentField;
    if (currentField.childFields != null) {
      for (final child in currentField.childFields!) {
        if (child.key == depKey) return child;
      }
    }
    return null;
  }

  bool _evaluateCondition(
    FieldVisibilityCondition? condition,
    FormValues values,
  ) {
    if (condition == null) return true;

    final fieldValue = values.get(condition.dependentFieldKey);

    return switch (condition) {
      EqualsCondition(:final value) => fieldValue == value,
      NotEqualsCondition(:final value) => fieldValue != value,
      ContainsCondition(:final value) =>
        fieldValue is Iterable && fieldValue.contains(value),
      IsEmptyCondition() =>
        fieldValue == null ||
        (fieldValue is String && fieldValue.isEmpty) ||
        (fieldValue is Iterable && fieldValue.isEmpty),
      IsNotEmptyCondition() =>
        fieldValue != null &&
        !(fieldValue is String && fieldValue.isEmpty) &&
        !(fieldValue is Iterable && fieldValue.isEmpty),
      CustomVisibilityCondition(:final evaluatorKey, :final parameters) =>
        _evaluateCustom(evaluatorKey, parameters, fieldValue),
    };
  }

  bool _evaluateCustom(
    String evaluatorKey,
    Map<String, String> parameters,
    dynamic fieldValue,
  ) {
    final evaluator = _customEvaluators[evaluatorKey];
    if (evaluator == null) {
      AppLogger.warning(
        _tag,
        'Custom visibility evaluator "$evaluatorKey" not found.',
      );
      return false;
    }

    return evaluator.evaluate(
      fieldValue: fieldValue,
      parameters: parameters,
    );
  }

  // ── Cycle Detection ────────────────────────────────────────────────────────

  void _detectCycles(Map<String, List<String>> graph) {
    final visited = <String>{};
    final inStack = <String>{};

    for (final node in graph.keys) {
      if (!_dfsVisit(node, graph, visited, inStack, [])) {
        final cycle = _findCyclePath(node, graph);
        throw FieldDependencyCycleException(
          message: 'Circular dependency detected in form fields.',
          fieldKeys: cycle,
        );
      }
    }
  }

  bool _dfsVisit(
    String node,
    Map<String, List<String>> graph,
    Set<String> visited,
    Set<String> inStack,
    List<String> path,
  ) {
    if (inStack.contains(node)) return false;
    if (visited.contains(node)) return true;

    inStack.add(node);
    visited.add(node);

    final dependencies = graph[node] ?? [];
    for (final dep in dependencies) {
      if (!_dfsVisit(dep, graph, visited, inStack, [...path, dep])) {
        return false;
      }
    }

    inStack.remove(node);
    return true;
  }

  List<String> _findCyclePath(String node, Map<String, List<String>> graph) {
    final path = [node];
    var current = node;
    final visited = <String>{};

    while (!visited.contains(current)) {
      visited.add(current);
      final deps = graph[current] ?? [];
      if (deps.isEmpty) break;
      current = deps.first;
      path.add(current);
    }

    return path;
  }
}

/// Custom visibility evaluator — for complex visibility logic.
abstract class CustomVisibilityEvaluator {
  const CustomVisibilityEvaluator();
  bool evaluate({
    required dynamic fieldValue,
    required Map<String, String> parameters,
  });
}
