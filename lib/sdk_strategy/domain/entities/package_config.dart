/// Package configuration — represents a modular SDK package.
///
/// Design rationale:
/// - Each package is independently versioned and publishable.
/// - Packages have strict dependency boundaries.
/// - Packages declare their stability level (stable, beta, experimental).
/// - Packages track their pub.dev score and adoption metrics.
/// - Packages have ownership for maintenance accountability.
///
/// Package ecosystem:
///   flutter_runtime_core — foundation utilities, logging, DI, error handling
///   flutter_auth_engine — authentication, sessions, guards
///   flutter_network_engine — API client, interceptors, offline sync
///   flutter_permission_engine — RBAC, permissions, guards
///   flutter_offline_engine — sync engine, conflict resolution
///   flutter_feature_control — feature flags, remote config
///   flutter_forms_engine — smart forms, workflows
///   flutter_billing_engine — subscriptions, entitlements
///   flutter_observability_engine — logging, audit, tracing
///   flutter_multi_tenant_engine — tenant isolation, white-label
///   flutter_release_engineering — CI/CD, rollout, rollback
class PackageConfig {
  const PackageConfig({
    required this.name,
    required this.description,
    required this.category,
    required this.stability,
    required this.version,
    required this.dependencies,
    required this.owners,
    this.sdkConstraint = '>=3.0.0',
    this.flutterConstraint = '>=3.16.0',
    this.externalDependencies = const [],
    this.hasExamples = false,
    this.hasTests = false,
    this.hasDocumentation = false,
    this.pubDevScore,
    this.weeklyDownloads,
    this.githubStars,
    this.tags = const [],
  });

  final String name;
  final String description;
  final PackageCategory category;
  final PackageStability stability;
  final String version;
  final List<String> dependencies;
  final List<String> owners;
  final String sdkConstraint;
  final String flutterConstraint;
  final List<String> externalDependencies;
  final bool hasExamples;
  final bool hasTests;
  final bool hasDocumentation;
  final int? pubDevScore;
  final int? weeklyDownloads;
  final int? githubStars;
  final List<String> tags;

  bool get isStable => stability == PackageStability.stable;
  bool get isExperimental => stability == PackageStability.experimental;
  bool get isBeta => stability == PackageStability.beta;

  bool get isPublishReady =>
      hasExamples && hasTests && hasDocumentation && isStable;

  bool dependsOn(String packageName) {
    return dependencies.contains(packageName);
  }

  bool get isCorePackage => category == PackageCategory.core;
  bool get isEnginePackage => category == PackageCategory.engine;
  bool get isExtensionPackage => category == PackageCategory.extension;
}

enum PackageCategory {
  core,
  engine,
  extension,
}

enum PackageStability {
  experimental,
  beta,
  stable,
  deprecated,
}

/// Package readiness result — outcome of package publish readiness check.
sealed class PackageReadinessResult {
  const PackageReadinessResult({required this.packageName});
  final String packageName;

  bool get isReady => this is PackagePublishValidated;
}

/// Package is ready for pub.dev publication.
final class PackagePublishValidated extends PackageReadinessResult {
  const PackagePublishValidated({
    required super.packageName,
    required this.score,
    this.checks = const [],
  });
  final int score;
  final List<String> checks;
}

/// Package blocked by breaking change risk.
final class BlockedByBreakingChangeRisk extends PackageReadinessResult {
  const BlockedByBreakingChangeRisk({
    required super.packageName,
    required this.breakingChanges,
    this.migrationGuideUrl,
  });
  final List<String> breakingChanges;
  final String? migrationGuideUrl;
}

/// Package blocked by missing documentation.
final class BlockedByMissingDocumentation extends PackageReadinessResult {
  const BlockedByMissingDocumentation({
    required super.packageName,
    required this.missingDocs,
  });
  final List<String> missingDocs;
}

/// Package blocked by failing tests.
final class BlockedByFailingTests extends PackageReadinessResult {
  const BlockedByFailingTests({
    required super.packageName,
    required this.failingTests,
  });
  final List<String> failingTests;
}

/// Package blocked by dependency violation.
final class BlockedByDependencyViolation extends PackageReadinessResult {
  const BlockedByDependencyViolation({
    required super.packageName,
    required this.violation,
    this.violatedDependency,
  });
  final String violation;
  final String? violatedDependency;
}
