/// Starter template manager — manages production-ready starter templates.
///
/// Design rationale:
/// - Templates are real production examples, not todo apps.
/// - Each template includes full architecture with all modules.
/// - Templates are versioned and compatible with framework versions.
/// - Templates can be customized during generation.
///
/// Available templates:
/// - saas_app — Multi-tenant SaaS with auth, billing, offline sync.
/// - clinic_system — Healthcare clinic management with HIPAA compliance.
/// - crm_platform — Enterprise CRM with multi-tenant isolation.
/// - white_label_b2b — White-label B2B platform for multiple clients.
/// - admin_dashboard — Admin-heavy platform with observability + audit.
class StarterTemplateManager {
  const StarterTemplateManager();

  /// Get all available templates.
  List<TemplateConfig> getAvailableTemplates() {
    return _templates;
  }

  /// Get a template by name.
  TemplateConfig? getTemplateByName(String name) {
    return _templates.firstWhere(
      (t) => t.name == name,
      orElse: () => _templates.first,
    );
  }

  /// Validate that a template is compatible with the current framework version.
  bool isTemplateCompatible(String templateName, String frameworkVersion) {
    final template = getTemplateByName(templateName);
    if (template == null) return false;
    return template.compatibleVersions.contains(frameworkVersion);
  }

  /// Generate template configuration.
  Map<String, dynamic> generateTemplateConfig({
    required String templateName,
    required String projectName,
    Map<String, String>? customizations,
  }) {
    final template = getTemplateByName(templateName);
    if (template == null) {
      throw Exception('Template not found: $templateName');
    }

    return {
      'project_name': projectName,
      'template': templateName,
      'modules': template.requiredModules,
      'flavors': template.flavors,
      'architecture': template.architecture,
      'customizations': customizations ?? {},
    };
  }

  static const List<TemplateConfig> _templates = [
    TemplateConfig(
      name: 'saas_app',
      description: 'Multi-tenant SaaS platform with auth, billing, and offline sync',
      requiredModules: [
        'auth',
        'network',
        'permission',
        'offline',
        'billing',
        'multi_tenant',
        'observability',
      ],
      flavors: ['dev', 'staging', 'prod'],
      architecture: 'clean',
      compatibleVersions: ['1.0.0', '1.1.0', '1.2.0'],
      estimatedSetupMinutes: 30,
    ),
    TemplateConfig(
      name: 'clinic_system',
      description: 'Healthcare clinic management with HIPAA compliance',
      requiredModules: [
        'auth',
        'network',
        'permission',
        'offline',
        'forms',
        'multi_tenant',
        'observability',
      ],
      flavors: ['dev', 'staging', 'prod'],
      architecture: 'clean',
      compatibleVersions: ['1.0.0', '1.1.0', '1.2.0'],
      estimatedSetupMinutes: 45,
    ),
    TemplateConfig(
      name: 'crm_platform',
      description: 'Enterprise CRM with multi-tenant isolation and forms',
      requiredModules: [
        'auth',
        'network',
        'permission',
        'forms',
        'feature_control',
        'multi_tenant',
        'observability',
      ],
      flavors: ['dev', 'staging', 'prod'],
      architecture: 'clean',
      compatibleVersions: ['1.0.0', '1.1.0', '1.2.0'],
      estimatedSetupMinutes: 30,
    ),
    TemplateConfig(
      name: 'white_label_b2b',
      description: 'White-label B2B platform for multiple clients',
      requiredModules: [
        'auth',
        'network',
        'multi_tenant',
        'release_engineering',
        'observability',
      ],
      flavors: ['dev', 'demo', 'prod'],
      architecture: 'clean',
      compatibleVersions: ['1.0.0', '1.1.0', '1.2.0'],
      estimatedSetupMinutes: 45,
    ),
    TemplateConfig(
      name: 'admin_dashboard',
      description: 'Admin-heavy platform with observability and audit',
      requiredModules: [
        'auth',
        'network',
        'permission',
        'observability',
        'feature_control',
      ],
      flavors: ['dev', 'staging', 'prod'],
      architecture: 'clean',
      compatibleVersions: ['1.0.0', '1.1.0', '1.2.0'],
      estimatedSetupMinutes: 20,
    ),
  ];
}

/// Template configuration — represents a starter template.
class TemplateConfig {
  const TemplateConfig({
    required this.name,
    required this.description,
    required this.requiredModules,
    required this.flavors,
    required this.architecture,
    required this.compatibleVersions,
    required this.estimatedSetupMinutes,
  });

  final String name;
  final String description;
  final List<String> requiredModules;
  final List<String> flavors;
  final String architecture;
  final List<String> compatibleVersions;
  final int estimatedSetupMinutes;
}
