/// DX documentation engine — manages developer documentation strategy.
///
/// Design rationale:
/// - Documentation is a product, not a side task.
/// - Each doc type serves a specific developer need.
/// - Documentation is versioned and updated with releases.
/// - Quick Start docs are prioritized for new developers.
///
/// Documentation types:
/// - quick_start.md — Get started in 5 minutes.
/// - production_setup.md — Production deployment guide.
/// - architecture_deep_dive.md — Architecture decisions and patterns.
/// - white_label_setup.md — White-label configuration guide.
/// - offline_sync_guide.md — Offline sync implementation guide.
/// - billing_integration.md — Billing integration guide.
/// - release_safety.md — Release safety and rollback guide.
/// - contributor_guide.md — How to contribute to the framework.
/// - migration_guides/ — Version-to-version migration guides.
/// - troubleshooting.md — Troubleshooting handbook.
class DXDocumentationEngine {
  const DXDocumentationEngine();

  /// Get all documentation categories.
  List<DocCategory> getDocCategories() {
    return _docCategories;
  }

  /// Get documentation for a specific topic.
  DocTopic? getTopic(String topic) {
    return _topics[topic];
  }

  /// Get quick start guide.
  DocTopic getQuickStartGuide() {
    return _topics['quick_start']!;
  }

  /// Get migration guide for a version.
  DocTopic? getMigrationGuide(String version) {
    return _topics['migration_$version'];
  }

  static const List<DocCategory> _docCategories = [
    DocCategory(
      name: 'Getting Started',
      topics: ['quick_start', 'installation', 'project_setup'],
    ),
    DocCategory(
      name: 'Core Modules',
      topics: ['auth', 'network', 'permissions', 'offline', 'billing'],
    ),
    DocCategory(
      name: 'Advanced',
      topics: ['multi_tenant', 'release_engineering', 'white_label'],
    ),
    DocCategory(
      name: 'Production',
      topics: ['production_setup', 'release_safety', 'monitoring'],
    ),
    DocCategory(
      name: 'Contributing',
      topics: ['contributor_guide', 'architecture_decisions', 'review_process'],
    ),
    DocCategory(
      name: 'Migration',
      topics: ['migration_1.0', 'migration_1.1', 'migration_1.2'],
    ),
  ];

  static const Map<String, DocTopic> _topics = {
    'quick_start': DocTopic(
      id: 'quick_start',
      title: 'Quick Start — Get Started in 5 Minutes',
      description: 'Bootstrap a production-ready Flutter app in minutes.',
      estimatedReadTimeMinutes: 5,
      priority: 1,
    ),
    'production_setup': DocTopic(
      id: 'production_setup',
      title: 'Production Setup Guide',
      description: 'Configure your app for production deployment.',
      estimatedReadTimeMinutes: 15,
      priority: 2,
    ),
    'architecture_deep_dive': DocTopic(
      id: 'architecture_deep_dive',
      title: 'Architecture Deep Dive',
      description: 'Understand the framework architecture and design decisions.',
      estimatedReadTimeMinutes: 30,
      priority: 3,
    ),
    'white_label_setup': DocTopic(
      id: 'white_label_setup',
      title: 'White-Label Setup Guide',
      description: 'Configure white-label branding for multiple clients.',
      estimatedReadTimeMinutes: 20,
      priority: 4,
    ),
    'offline_sync_guide': DocTopic(
      id: 'offline_sync_guide',
      title: 'Offline Sync Guide',
      description: 'Implement offline-first with conflict resolution.',
      estimatedReadTimeMinutes: 25,
      priority: 5,
    ),
    'billing_integration': DocTopic(
      id: 'billing_integration',
      title: 'Billing Integration Guide',
      description: 'Add subscriptions, entitlements, and payment recovery.',
      estimatedReadTimeMinutes: 20,
      priority: 6,
    ),
    'release_safety': DocTopic(
      id: 'release_safety',
      title: 'Release Safety Guide',
      description: 'Safe deployment with staged rollout and rollback.',
      estimatedReadTimeMinutes: 15,
      priority: 7,
    ),
    'contributor_guide': DocTopic(
      id: 'contributor_guide',
      title: 'Contributor Guide',
      description: 'How to contribute to the framework.',
      estimatedReadTimeMinutes: 10,
      priority: 8,
    ),
    'troubleshooting': DocTopic(
      id: 'troubleshooting',
      title: 'Troubleshooting Handbook',
      description: 'Common issues and their solutions.',
      estimatedReadTimeMinutes: 20,
      priority: 9,
    ),
  };
}

/// Documentation topic — represents a single documentation page.
class DocTopic {
  const DocTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedReadTimeMinutes,
    required this.priority,
  });

  final String id;
  final String title;
  final String description;
  final int estimatedReadTimeMinutes;
  final int priority;
}

/// Documentation category — groups related documentation topics.
class DocCategory {
  const DocCategory({
    required this.name,
    required this.topics,
  });

  final String name;
  final List<String> topics;
}

/// Onboarding docs manager — manages onboarding documentation flow.
class OnboardingDocsManager {
  const OnboardingDocsManager();

  /// Get the recommended onboarding documentation path.
  List<DocTopic> getOnboardingPath() {
    return const [
      DocTopic(
        id: 'quick_start',
        title: 'Quick Start',
        description: 'Get started in 5 minutes',
        estimatedReadTimeMinutes: 5,
        priority: 1,
      ),
      DocTopic(
        id: 'project_setup',
        title: 'Project Setup',
        description: 'Configure your project structure',
        estimatedReadTimeMinutes: 10,
        priority: 2,
      ),
      DocTopic(
        id: 'first_module',
        title: 'Add Your First Module',
        description: 'Add auth, network, or billing module',
        estimatedReadTimeMinutes: 10,
        priority: 3,
      ),
      DocTopic(
        id: 'production_setup',
        title: 'Production Setup',
        description: 'Prepare for production deployment',
        estimatedReadTimeMinutes: 15,
        priority: 4,
      ),
    ];
  }
}
