/// Example app strategy — manages example app architecture for SDK adoption.
///
/// Design rationale:
/// - Example apps demonstrate real-world usage, not toy examples.
/// - Each example app targets a specific use case and audience.
/// - Example apps are self-contained and runnable.
/// - Example apps integrate multiple SDK packages to show composition.
///
/// Example app portfolio:
/// - Clinic SaaS — multi-tenant healthcare platform (auth, billing, offline sync).
/// - Multi-tenant CRM — enterprise CRM with tenant isolation.
/// - Billing-heavy platform — subscription management + entitlements.
/// - White-label B2B — branded app for multiple clients.
/// - Production dashboard — observability + monitoring + audit.
/// - Quick start — minimal setup for new developers.
class ExampleAppStrategy {
  const ExampleAppStrategy({
    this.exampleApps = const [
      ExampleAppConfig(
        name: 'clinic_saas',
        description: 'Multi-tenant healthcare SaaS platform',
        packages: [
          'flutter_runtime_core',
          'flutter_auth_engine',
          'flutter_network_engine',
          'flutter_permission_engine',
          'flutter_offline_engine',
          'flutter_billing_engine',
          'flutter_multi_tenant_engine',
        ],
        complexity: ExampleAppComplexity.advanced,
        targetAudience: 'healthcare_saaS',
      ),
      ExampleAppConfig(
        name: 'multi_tenant_crm',
        description: 'Enterprise CRM with tenant isolation',
        packages: [
          'flutter_runtime_core',
          'flutter_auth_engine',
          'flutter_network_engine',
          'flutter_permission_engine',
          'flutter_forms_engine',
          'flutter_multi_tenant_engine',
        ],
        complexity: ExampleAppComplexity.advanced,
        targetAudience: 'enterprise',
      ),
      ExampleAppConfig(
        name: 'billing_platform',
        description: 'Subscription management + entitlements',
        packages: [
          'flutter_runtime_core',
          'flutter_auth_engine',
          'flutter_billing_engine',
          'flutter_observability_engine',
        ],
        complexity: ExampleAppComplexity.intermediate,
        targetAudience: 'saas_builders',
      ),
      ExampleAppConfig(
        name: 'white_label_b2b',
        description: 'White-label B2B system for multiple clients',
        packages: [
          'flutter_runtime_core',
          'flutter_auth_engine',
          'flutter_network_engine',
          'flutter_multi_tenant_engine',
          'flutter_release_engineering',
        ],
        complexity: ExampleAppComplexity.advanced,
        targetAudience: 'white_label_vendors',
      ),
      ExampleAppConfig(
        name: 'production_dashboard',
        description: 'Observability + monitoring + audit dashboard',
        packages: [
          'flutter_runtime_core',
          'flutter_observability_engine',
          'flutter_feature_control',
        ],
        complexity: ExampleAppComplexity.intermediate,
        targetAudience: 'engineering_teams',
      ),
      ExampleAppConfig(
        name: 'quick_start',
        description: 'Minimal setup for new developers',
        packages: [
          'flutter_runtime_core',
        ],
        complexity: ExampleAppComplexity.beginner,
        targetAudience: 'new_developers',
      ),
    ],
  });

  final List<ExampleAppConfig> exampleApps;

  /// Get example apps by target audience.
  List<ExampleAppConfig> getByAudience(String audience) {
    return exampleApps.where((app) => app.targetAudience == audience).toList();
  }

  /// Get example apps by complexity.
  List<ExampleAppConfig> getByComplexity(ExampleAppComplexity complexity) {
    return exampleApps.where((app) => app.complexity == complexity).toList();
  }

  /// Get example apps that use a specific package.
  List<ExampleAppConfig> getByPackage(String packageName) {
    return exampleApps.where((app) => app.packages.contains(packageName)).toList();
  }

  /// Get the recommended example app for a new developer.
  ExampleAppConfig? getRecommendedForNewDeveloper() {
    return exampleApps.firstWhere(
      (app) => app.complexity == ExampleAppComplexity.beginner,
      orElse: () => exampleApps.first,
    );
  }

  /// Validate that all packages have example coverage.
  Map<String, bool> validatePackageCoverage(List<String> allPackages) {
    final coverage = <String, bool>{};
    for (final pkg in allPackages) {
      coverage[pkg] = exampleApps.any((app) => app.packages.contains(pkg));
    }
    return coverage;
  }
}

/// Example app configuration.
class ExampleAppConfig {
  const ExampleAppConfig({
    required this.name,
    required this.description,
    required this.packages,
    required this.complexity,
    required this.targetAudience,
    this.hasTests = false,
    this.hasDocumentation = false,
    this.isRunnable = false,
  });

  final String name;
  final String description;
  final List<String> packages;
  final ExampleAppComplexity complexity;
  final String targetAudience;
  final bool hasTests;
  final bool hasDocumentation;
  final bool isRunnable;
}

enum ExampleAppComplexity {
  beginner,
  intermediate,
  advanced,
}
