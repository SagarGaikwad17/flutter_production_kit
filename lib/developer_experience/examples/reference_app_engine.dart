/// Reference app engine — manages real-world reference applications.
///
/// Design rationale:
/// - Reference apps demonstrate production architecture patterns.
/// - Each reference app is a complete, runnable application.
/// - Reference apps include real business logic, not just UI demos.
/// - Reference apps can be used as starting points for new projects.
///
/// Reference app portfolio:
/// - saas_reference — Full SaaS with auth, billing, multi-tenant, offline.
/// - clinic_reference — Healthcare with HIPAA compliance, forms, sync.
/// - crm_reference — Enterprise CRM with permissions, workflows.
/// - white_label_reference — White-label with branding, tenant isolation.
class ReferenceAppEngine {
  const ReferenceAppEngine();

  /// Get all available reference apps.
  List<ReferenceAppConfig> getReferenceApps() {
    return _referenceApps;
  }

  /// Get a reference app by name.
  ReferenceAppConfig? getByName(String name) {
    try {
      return _referenceApps.firstWhere((app) => app.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get reference apps by industry.
  List<ReferenceAppConfig> getByIndustry(String industry) {
    return _referenceApps.where((app) => app.industry == industry).toList();
  }

  /// Get reference apps by complexity.
  List<ReferenceAppConfig> getByComplexity(ReferenceAppComplexity complexity) {
    return _referenceApps.where((app) => app.complexity == complexity).toList();
  }

  static const List<ReferenceAppConfig> _referenceApps = [
    ReferenceAppConfig(
      name: 'saas_reference',
      description: 'Full SaaS application with auth, billing, multi-tenant, and offline sync',
      industry: 'saas',
      complexity: ReferenceAppComplexity.advanced,
      modules: [
        'auth',
        'network',
        'permission',
        'offline',
        'billing',
        'multi_tenant',
        'observability',
      ],
      features: [
        'User registration and authentication',
        'Subscription management with grace periods',
        'Multi-tenant isolation with branch scoping',
        'Offline sync with conflict resolution',
        'Production observability with audit trails',
      ],
      estimatedStudyTimeHours: 8,
    ),
    ReferenceAppConfig(
      name: 'clinic_reference',
      description: 'Healthcare clinic management with HIPAA compliance',
      industry: 'healthcare',
      complexity: ReferenceAppComplexity.advanced,
      modules: [
        'auth',
        'network',
        'permission',
        'offline',
        'forms',
        'multi_tenant',
        'observability',
      ],
      features: [
        'Patient registration and records',
        'Appointment scheduling',
        'HIPAA-compliant data handling',
        'Offline access to patient records',
        'Audit trail for compliance',
      ],
      estimatedStudyTimeHours: 12,
    ),
    ReferenceAppConfig(
      name: 'crm_reference',
      description: 'Enterprise CRM with multi-tenant isolation and workflows',
      industry: 'enterprise',
      complexity: ReferenceAppComplexity.advanced,
      modules: [
        'auth',
        'network',
        'permission',
        'forms',
        'feature_control',
        'multi_tenant',
        'observability',
      ],
      features: [
        'Contact and lead management',
        'Role-based access control',
        'Smart forms for data entry',
        'Feature flags for gradual rollout',
        'Multi-tenant data isolation',
      ],
      estimatedStudyTimeHours: 10,
    ),
    ReferenceAppConfig(
      name: 'white_label_reference',
      description: 'White-label B2B platform for multiple clients',
      industry: 'b2b',
      complexity: ReferenceAppComplexity.advanced,
      modules: [
        'auth',
        'network',
        'multi_tenant',
        'release_engineering',
        'observability',
      ],
      features: [
        'Client-specific branding',
        'Tenant-aware theming',
        'Safe release orchestration',
        'Cross-tenant isolation',
        'Production monitoring',
      ],
      estimatedStudyTimeHours: 8,
    ),
  ];
}

/// Reference app configuration.
class ReferenceAppConfig {
  const ReferenceAppConfig({
    required this.name,
    required this.description,
    required this.industry,
    required this.complexity,
    required this.modules,
    required this.features,
    required this.estimatedStudyTimeHours,
  });

  final String name;
  final String description;
  final String industry;
  final ReferenceAppComplexity complexity;
  final List<String> modules;
  final List<String> features;
  final int estimatedStudyTimeHours;
}

enum ReferenceAppComplexity {
  beginner,
  intermediate,
  advanced,
}
