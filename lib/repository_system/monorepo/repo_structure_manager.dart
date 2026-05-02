import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Repository structure manager — manages monorepo package organization.
///
/// Design rationale:
/// - Monorepo is organized into packages with clear boundaries.
/// - Each package has a defined owner and dependency rules.
/// - Circular dependencies are strictly forbidden.
/// - Package structure is validated before any changes.
///
/// Monorepo structure:
///   packages/
///     flutter_runtime_core/        — Foundation utilities
///     flutter_auth_engine/         — Authentication
///     flutter_network_engine/      — API runtime
///     flutter_permission_engine/   — RBAC
///     flutter_offline_engine/      — Offline sync
///     flutter_feature_control/     — Feature flags
///     flutter_forms_engine/        — Smart forms
///     flutter_billing_engine/      — Billing
///     flutter_observability_engine/— Observability
///     flutter_multi_tenant_engine/ — Multi-tenant
///     flutter_release_engineering/ — CI/CD
///     flutter_sdk_strategy/        — SDK packaging
///     flutter_developer_experience/— DX
///     flutter_repository_system/   — GitHub foundation
class RepoStructureManager {
  const RepoStructureManager({
    required IRepoStructureRepository repoStructureRepository,
  }) : _repoStructureRepository = repoStructureRepository;

  final IRepoStructureRepository _repoStructureRepository;

  /// Validate the monorepo structure.
  Future<RepoResult> validateMonorepo() async {
    final packages = await _repoStructureRepository.getPackages();
    final dependencyGraph = await _repoStructureRepository.getDependencyGraph();
    final violations = <String>[];

    // Check for circular dependencies
    final circular = _detectCircularDependencies(dependencyGraph);
    if (circular.isNotEmpty) {
      violations.addAll(circular.map((c) => 'Circular dependency: $c'));
    }

    // Check package boundary violations
    for (final entry in dependencyGraph.entries) {
      final package = entry.key;
      final deps = entry.value;
      final allowed = await _repoStructureRepository.getPackageBoundary(package);
      for (final dep in deps) {
        if (allowed.isNotEmpty && !allowed.contains(dep)) {
          violations.add(
            'Package "$package" depends on "$dep" (not in allowed list)',
          );
        }
      }
    }

    if (violations.isNotEmpty) {
      throw MonorepoStructureInvalidException(
        message: 'Monorepo structure validation failed',
        violations: violations,
      );
    }

    return MonorepoValidationPassed(
      operation: 'validate_monorepo',
      packageCount: packages.length,
    );
  }

  /// Validate a package's dependencies.
  Future<RepoResult> validatePackageDependencies({
    required String packageName,
    required List<String> dependencies,
  }) async {
    final allowed = await _repoStructureRepository.getPackageBoundary(packageName);
    final violations = <String>[];

    for (final dep in dependencies) {
      if (allowed.isNotEmpty && !allowed.contains(dep)) {
        violations.add(
          'Package "$packageName" cannot depend on "$dep"',
        );
      }
    }

    if (violations.isNotEmpty) {
      throw PackageBoundaryViolationException(
        message: 'Package boundary violation',
        sourcePackage: packageName,
        targetPackage: violations.first.split('"').last,
      );
    }

    return MonorepoValidationPassed(
      operation: 'validate_package_dependencies',
      packageCount: dependencies.length,
    );
  }

  /// Detect circular dependencies in a dependency graph.
  List<String> _detectCircularDependencies(Map<String, List<String>> graph) {
    final circular = <String>[];
    final visited = <String>{};
    final stack = <String>{};

    for (final node in graph.keys) {
      if (_hasCycle(node, graph, visited, stack, circular)) {
        break;
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
        circular.add('$node → $dep → ... → $node');
        return true;
      }
    }

    stack.remove(node);
    return false;
  }
}

/// Package boundary rules — enforces dependency discipline in monorepo.
class PackageBoundaryRules {
  const PackageBoundaryRules({
    this.layerRules = const {
      'core': [],
      'engine': ['core'],
      'extension': ['core', 'engine'],
      'meta': ['core', 'engine', 'extension'],
    },
    this.packageLayers = const {
      'flutter_runtime_core': 'core',
      'flutter_auth_engine': 'engine',
      'flutter_network_engine': 'engine',
      'flutter_permission_engine': 'engine',
      'flutter_offline_engine': 'engine',
      'flutter_feature_control': 'engine',
      'flutter_forms_engine': 'engine',
      'flutter_billing_engine': 'engine',
      'flutter_observability_engine': 'engine',
      'flutter_multi_tenant_engine': 'engine',
      'flutter_release_engineering': 'engine',
      'flutter_sdk_strategy': 'engine',
      'flutter_developer_experience': 'engine',
      'flutter_repository_system': 'engine',
    },
    this.forbiddenDependencies = const {},
  });

  final Map<String, List<String>> layerRules;
  final Map<String, String> packageLayers;
  final Map<String, List<String>> forbiddenDependencies;

  /// Check if a dependency is allowed.
  bool isDependencyAllowed({
    required String sourcePackage,
    required String targetPackage,
  }) {
    final sourceLayer = packageLayers[sourcePackage];
    final targetLayer = packageLayers[targetPackage];

    if (sourceLayer == null || targetLayer == null) return false;

    final allowedLayers = layerRules[sourceLayer] ?? [];
    return allowedLayers.contains(targetLayer);
  }

  /// Check if a dependency is forbidden.
  bool isDependencyForbidden({
    required String sourcePackage,
    required String targetPackage,
  }) {
    final forbidden = forbiddenDependencies[sourcePackage];
    return forbidden != null && forbidden.contains(targetPackage);
  }

  /// Get allowed dependencies for a package.
  List<String> getAllowedDependencies(String packageName) {
    final layer = packageLayers[packageName];
    if (layer == null) return [];

    final allowedLayers = layerRules[layer] ?? [];
    return packageLayers.entries
        .where((e) => allowedLayers.contains(e.value))
        .map((e) => e.key)
        .toList();
  }
}
