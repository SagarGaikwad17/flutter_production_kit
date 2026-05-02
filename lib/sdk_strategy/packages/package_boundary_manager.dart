import 'package:flutter_production_kit/sdk_strategy/domain/entities/package_config.dart';

/// Package boundary manager — enforces modular package boundaries.
///
/// Design rationale:
/// - Packages are organized in layers: core → engine → extension.
/// - Core packages cannot depend on engine or extension packages.
/// - Engine packages can depend on core packages.
/// - Extension packages can depend on core and engine packages.
/// - Circular dependencies are strictly forbidden.
///
/// Package ecosystem structure:
///   CORE (no internal dependencies):
///     - flutter_runtime_core
///
///   ENGINES (depend on core only):
///     - flutter_auth_engine
///     - flutter_network_engine
///     - flutter_permission_engine
///     - flutter_offline_engine
///     - flutter_feature_control
///     - flutter_forms_engine
///     - flutter_billing_engine
///     - flutter_observability_engine
///     - flutter_multi_tenant_engine
///     - flutter_release_engineering
///
///   EXTENSIONS (depend on core + engines):
///     - flutter_production_kit (meta-package)
class PackageBoundaryManager {
  const PackageBoundaryManager({
    this.layerRules = const {
      PackageCategory.core: [],
      PackageCategory.engine: [PackageCategory.core],
      PackageCategory.extension: [PackageCategory.core, PackageCategory.engine],
    },
    this.forbiddenDependencies = const {
      'flutter_runtime_core': ['flutter_auth_engine', 'flutter_network_engine'],
    },
    this.metaPackages = const ['flutter_production_kit'],
  });

  final Map<PackageCategory, List<PackageCategory>> layerRules;
  final Map<String, List<String>> forbiddenDependencies;
  final List<String> metaPackages;

  /// Validate that a package's dependencies respect boundary rules.
  PackageReadinessResult validateBoundaries({
    required String packageName,
    required PackageCategory category,
    required List<String> dependencies,
  }) {
    final violations = <String>[];

    for (final dep in dependencies) {
      // Check forbidden dependencies
      final forbidden = forbiddenDependencies[packageName];
      if (forbidden != null && forbidden.contains(dep)) {
        violations.add(
          'Package "$packageName" cannot depend on "$dep" (forbidden dependency)',
        );
        continue;
      }

      // Check circular dependencies
      if (dep == packageName) {
        violations.add('Package "$packageName" cannot depend on itself');
      }
    }

    if (violations.isNotEmpty) {
      return BlockedByDependencyViolation(
        packageName: packageName,
        violation: violations.first,
      );
    }

    return PackagePublishValidated(
      packageName: packageName,
      score: 100,
      checks: ['Boundary validation passed'],
    );
  }

  /// Check if a dependency is allowed for a package category.
  bool isDependencyAllowed({
    required PackageCategory sourceCategory,
    required PackageCategory targetCategory,
  }) {
    final allowed = layerRules[sourceCategory] ?? [];
    return allowed.contains(targetCategory);
  }

  /// Detect circular dependencies in a package graph.
  List<String> detectCircularDependencies(
    Map<String, List<String>> dependencyGraph,
  ) {
    final circular = <String>[];
    final visited = <String>{};
    final recursionStack = <String>{};

    for (final package in dependencyGraph.keys) {
      if (_hasCycle(
        package,
        dependencyGraph,
        visited,
        recursionStack,
        circular,
      )) {
        break;
      }
    }

    return circular;
  }

  bool _hasCycle(
    String package,
    Map<String, List<String>> graph,
    Set<String> visited,
    Set<String> stack,
    List<String> circular,
  ) {
    visited.add(package);
    stack.add(package);

    for (final dep in graph[package] ?? const []) {
      if (!visited.contains(dep)) {
        if (_hasCycle(dep, graph, visited, stack, circular)) return true;
      } else if (stack.contains(dep)) {
        circular.add('$package → $dep → ... → $package');
        return true;
      }
    }

    stack.remove(package);
    return false;
  }
}

/// Dependency graph policy — enforces dependency graph discipline.
class DependencyGraphPolicy {
  const DependencyGraphPolicy({
    this.maxDependencies = 10,
    this.maxTransitiveDependencies = 50,
    this.requireStableDependencies = true,
    this.forbidUnmaintainedDependencies = true,
    this.allowedExternalDependencies = const [
      'http',
      'get_it',
      'go_router',
      'flutter_secure_storage',
      'connectivity_plus',
      'logger',
      'shared_preferences',
      'sqflite',
      'hive',
      'isar',
      'equatable',
      'freezed_annotation',
      'json_annotation',
      'intl',
    ],
  });

  final int maxDependencies;
  final int maxTransitiveDependencies;
  final bool requireStableDependencies;
  final bool forbidUnmaintainedDependencies;
  final List<String> allowedExternalDependencies;

  /// Validate a package's dependency graph.
  bool validateDependencyGraph({
    required List<String> directDependencies,
    required List<String> transitiveDependencies,
    List<String>? externalDependencies,
  }) {
    if (directDependencies.length > maxDependencies) return false;
    if (transitiveDependencies.length > maxTransitiveDependencies) return false;

    if (externalDependencies != null) {
      for (final dep in externalDependencies) {
        if (!allowedExternalDependencies.contains(dep)) return false;
      }
    }

    return true;
  }
}
