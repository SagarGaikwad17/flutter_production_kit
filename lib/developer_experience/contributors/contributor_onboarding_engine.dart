import 'package:flutter_production_kit/developer_experience/domain/entities/dx_result.dart';

/// Contributor onboarding engine — guides new contributors through setup.
///
/// Design rationale:
/// - Contributors need clear guidance to start contributing.
/// - Onboarding includes architecture understanding, not just setup.
/// - First issue is suggested based on contributor skill level.
/// - Onboarding progress is tracked for community analytics.
///
/// Onboarding flow:
///   1. Read contributor guide.
///   2. Set up development environment.
///   3. Understand architecture.
///   4. Pick first issue.
///   5. Submit first PR.
class ContributorOnboardingEngine {
  const ContributorOnboardingEngine();

  /// Start contributor onboarding.
  DXResult startOnboarding({
    required String contributorId,
    String? skillLevel,
  }) {
    return ContributorOnboardingApproved(
      operation: 'contributor_onboarding',
      contributorId: contributorId,
      requiredReadings: [
        'CONTRIBUTING.md',
        'ARCHITECTURE.md',
        'CODE_OF_CONDUCT.md',
      ],
      firstIssue: _getFirstIssueForSkillLevel(skillLevel),
    );
  }

  /// Get onboarding checklist for a contributor.
  List<OnboardingStep> getOnboardingChecklist() {
    return _onboardingSteps;
  }

  /// Get architecture overview for new contributors.
  ArchitectureOverview getArchitectureOverview() {
    return const ArchitectureOverview(
      layers: [
        ArchitectureLayer(
          name: 'Core',
          description: 'Foundation utilities, logging, DI, error handling',
          packages: ['flutter_runtime_core'],
        ),
        ArchitectureLayer(
          name: 'Engines',
          description: 'Domain-specific engines (auth, network, billing, etc.)',
          packages: [
            'flutter_auth_engine',
            'flutter_network_engine',
            'flutter_billing_engine',
            'flutter_offline_engine',
            'flutter_permission_engine',
            'flutter_feature_control',
            'flutter_forms_engine',
            'flutter_observability_engine',
            'flutter_multi_tenant_engine',
            'flutter_release_engineering',
          ],
        ),
        ArchitectureLayer(
          name: 'Extensions',
          description: 'Meta-package and integrations',
          packages: ['flutter_production_kit'],
        ),
      ],
      principles: [
        'Clean architecture with clear layer boundaries',
        'Convention over configuration',
        'Sealed result types — no bool-only checks',
        'Immutable state machines for critical flows',
        'Secret-safe — no credentials in logs or errors',
        'Modular adoption — use only what you need',
      ],
    );
  }

  String? _getFirstIssueForSkillLevel(String? skillLevel) {
    switch (skillLevel) {
      case 'beginner':
        return 'good first issue';
      case 'intermediate':
        return 'help wanted';
      case 'advanced':
        return 'architecture improvement';
      default:
        return 'good first issue';
    }
  }

  static const List<OnboardingStep> _onboardingSteps = [
    OnboardingStep(
      order: 1,
      title: 'Read CONTRIBUTING.md',
      description: 'Understand the contribution guidelines and standards.',
      estimatedTimeMinutes: 10,
    ),
    OnboardingStep(
      order: 2,
      title: 'Set up development environment',
      description: 'Install Flutter, Dart, and required tools.',
      estimatedTimeMinutes: 15,
    ),
    OnboardingStep(
      order: 3,
      title: 'Read ARCHITECTURE.md',
      description: 'Understand the framework architecture and design decisions.',
      estimatedTimeMinutes: 20,
    ),
    OnboardingStep(
      order: 4,
      title: 'Pick a first issue',
      description: 'Find an issue labeled "good first issue" or "help wanted".',
      estimatedTimeMinutes: 10,
    ),
    OnboardingStep(
      order: 5,
      title: 'Submit your first PR',
      description: 'Follow the PR template and submit for review.',
      estimatedTimeMinutes: 30,
    ),
  ];
}

/// Onboarding step — a single step in contributor onboarding.
class OnboardingStep {
  const OnboardingStep({
    required this.order,
    required this.title,
    required this.description,
    required this.estimatedTimeMinutes,
  });

  final int order;
  final String title;
  final String description;
  final int estimatedTimeMinutes;
}

/// Architecture overview — provides architecture understanding for contributors.
class ArchitectureOverview {
  const ArchitectureOverview({
    required this.layers,
    required this.principles,
  });

  final List<ArchitectureLayer> layers;
  final List<String> principles;
}

/// Architecture layer — represents a layer in the framework architecture.
class ArchitectureLayer {
  const ArchitectureLayer({
    required this.name,
    required this.description,
    required this.packages,
  });

  final String name;
  final String description;
  final List<String> packages;
}
