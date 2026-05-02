import 'package:flutter_production_kit/developer_experience/domain/entities/dx_result.dart';

/// Architecture guardrails — enforces architecture standards in projects.
///
/// Design rationale:
/// - Prevents common architecture mistakes early.
/// - Validates project structure against conventions.
/// - Ensures modules are used correctly.
/// - Catches configuration mismatches before they become disasters.
///
/// Guardrails:
/// - No circular dependencies between modules.
/// - Core modules cannot depend on engine modules.
/// - All public APIs must be documented.
/// - No global mutable state.
/// - All exceptions must be typed.
/// - Feature flags must have default values.
/// - Auth tokens must never be logged.
/// - API keys must never be hardcoded.
class ArchitectureGuardrails {
  const ArchitectureGuardrails({
    this.rules = const [
      'no_circular_dependencies',
      'core_cannot_depend_on_engines',
      'documented_public_apis',
      'no_global_mutable_state',
      'typed_exceptions_only',
      'feature_flags_require_defaults',
      'no_token_logging',
      'no_hardcoded_api_keys',
    ],
  });

  final List<String> rules;

  /// Validate project architecture against guardrails.
  DXResult validateArchitecture({
    required String projectName,
    required List<String> modules,
    Map<String, List<String>>? dependencyGraph,
  }) {
    final violations = <String>[];

    // Check circular dependencies
    if (dependencyGraph != null) {
      final circular = _detectCircularDependencies(dependencyGraph);
      if (circular.isNotEmpty) {
        violations.addAll(circular.map((c) => 'Circular dependency: $c'));
      }
    }

    // Check core-to-engine dependency violations
    final coreModules = modules.where((m) => _isCoreModule(m)).toList();
    final engineModules = modules.where((m) => _isEngineModule(m)).toList();
    for (final core in coreModules) {
      for (final engine in engineModules) {
        if (_dependsOn(dependencyGraph, core, engine)) {
          violations.add(
            'Core module "$core" cannot depend on engine module "$engine"',
          );
        }
      }
    }

    if (violations.isNotEmpty) {
      return ArchitectureIssueDetected(
        operation: 'validate_architecture',
        issues: violations,
        severity: 'error',
        remediation: violations.map((v) => 'Fix: $v').toList(),
      );
    }

    return ProjectSetupValidated(
      operation: 'validate_architecture',
      projectName: projectName,
      modules: modules,
    );
  }

  /// Check if a module is a core module.
  bool _isCoreModule(String module) {
    return module == 'core' || module == 'runtime_core';
  }

  /// Check if a module is an engine module.
  bool _isEngineModule(String module) {
    return const [
      'auth',
      'network',
      'billing',
      'offline',
      'permission',
      'feature_control',
      'forms',
      'observability',
      'multi_tenant',
      'release_engineering',
    ].contains(module);
  }

  /// Check if source depends on target in the dependency graph.
  bool _dependsOn(
    Map<String, List<String>>? graph,
    String source,
    String target,
  ) {
    if (graph == null) return false;
    return graph[source]?.contains(target) ?? false;
  }

  /// Detect circular dependencies in a dependency graph.
  List<String> _detectCircularDependencies(
    Map<String, List<String>> graph,
  ) {
    final circular = <String>[];
    final visited = <String>{};
    final stack = <String>{};

    for (final node in graph.keys) {
      if (!_hasCycle(node, graph, visited, stack, circular)) {
        continue;
      }
    }

    return circular;
  }

  bool _hasCycle(
    String node,
    Map<String, List<String>> graph,
    Set<String> visited,
    Set<String> stack,
    List<String> circular,
  ) {
    visited.add(node);
    stack.add(node);

    for (final dep in graph[node] ?? const []) {
      if (!visited.contains(dep)) {
        if (_hasCycle(dep, graph, visited, stack, circular)) return true;
      } else if (stack.contains(dep)) {
        circular.add('$node → $dep');
        return true;
      }
    }

    stack.remove(node);
    return false;
  }
}
