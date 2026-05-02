import 'package:flutter_production_kit/sdk_strategy/domain/repositories/sdk_repositories.dart';

/// Documentation engine — manages SDK documentation strategy.
///
/// Design rationale:
/// - Documentation is structured by audience and purpose.
/// - Each package must have minimum documentation coverage.
/// - Documentation types cover all developer needs.
/// - Documentation quality is scored for pub.dev readiness.
///
/// Documentation types:
/// - README.md — package overview, quick start.
/// - ARCHITECTURE.md — design decisions, component relationships.
/// - GETTING_STARTED.md — onboarding guide for new users.
/// - API_REFERENCE.md — complete API documentation.
/// - MIGRATION.md — version-to-version migration guides.
/// - PRODUCTION_SETUP.md — production deployment guide.
/// - TROUBLESHOOTING.md — common issues and solutions.
/// - CONTRIBUTING.md — contributor onboarding guide.
/// - SECURITY.md — security posture, best practices.
/// - ENTERPRISE.md — enterprise readiness documentation.
class DocumentationEngine {
  const DocumentationEngine({
    required IDocumentationRepository docRepository,
    this.minimumDocumentationScore = 0.80,
    this.requiredDocTypes = const [
      'README.md',
      'ARCHITECTURE.md',
      'GETTING_STARTED.md',
      'API_REFERENCE.md',
      'CONTRIBUTING.md',
    ],
    this.recommendedDocTypes = const [
      'MIGRATION.md',
      'PRODUCTION_SETUP.md',
      'TROUBLESHOOTING.md',
      'SECURITY.md',
      'ENTERPRISE.md',
    ],
  }) : _docRepository = docRepository;

  final IDocumentationRepository _docRepository;
  final double minimumDocumentationScore;
  final List<String> requiredDocTypes;
  final List<String> recommendedDocTypes;

  /// Get documentation status for a package.
  Future<DocumentationStatus> getDocumentationStatus(String packageName) async {
    final status = await _docRepository.getDocumentationStatus(packageName);
    final missingRequired = <String>[];
    final missingRecommended = <String>[];

    for (final docType in requiredDocTypes) {
      if (status[docType] != true) {
        missingRequired.add(docType);
      }
    }

    for (final docType in recommendedDocTypes) {
      if (status[docType] != true) {
        missingRecommended.add(docType);
      }
    }

    final totalDocs = requiredDocTypes.length + recommendedDocTypes.length;
    final completeDocs = status.values.where((v) => v).length;
    final score = totalDocs > 0 ? completeDocs / totalDocs : 0.0;

    return DocumentationStatus(
      packageName: packageName,
      score: score,
      hasAllRequired: missingRequired.isEmpty,
      missingRequired: missingRequired,
      missingRecommended: missingRecommended,
      isReadyForPubDev: missingRequired.isEmpty && score >= minimumDocumentationScore,
    );
  }

  /// Get missing documentation for a package.
  Future<List<String>> getMissingDocumentation(String packageName) async {
    return _docRepository.getMissingDocumentation(packageName);
  }

  /// Calculate documentation score for pub.dev readiness.
  double calculatePubDevScore({
    required bool hasReadme,
    required bool hasExample,
    required bool hasChangelog,
    required bool hasLicense,
    required double docCoverage,
    required bool hasPlatformSupport,
  }) {
    var score = 0.0;

    if (hasReadme) score += 15;
    if (hasExample) score += 15;
    if (hasChangelog) score += 10;
    if (hasLicense) score += 5;
    score += docCoverage * 30;
    if (hasPlatformSupport) score += 25;

    return score.clamp(0, 100);
  }
}

/// Documentation status — represents the documentation completeness of a package.
class DocumentationStatus {
  const DocumentationStatus({
    required this.packageName,
    required this.score,
    required this.hasAllRequired,
    required this.missingRequired,
    required this.missingRecommended,
    required this.isReadyForPubDev,
  });

  final String packageName;
  final double score;
  final bool hasAllRequired;
  final List<String> missingRequired;
  final List<String> missingRecommended;
  final bool isReadyForPubDev;
}

/// Architecture docs strategy — defines architecture documentation standards.
class ArchitectureDocsStrategy {
  const ArchitectureDocsStrategy({
    this.requireArchitectureDecisionRecords = true,
    this.requireComponentDiagrams = true,
    this.requireDataFlowDiagrams = true,
    this.requireSecurityArchitecture = true,
    this.requirePerformanceConsiderations = true,
  });

  final bool requireArchitectureDecisionRecords;
  final bool requireComponentDiagrams;
  final bool requireDataFlowDiagrams;
  final bool requireSecurityArchitecture;
  final bool requirePerformanceConsiderations;

  /// Get required architecture documentation sections.
  List<String> getRequiredSections() {
    final sections = <String>[
      'Overview',
      'Architecture Decision Records (ADRs)',
      'Component Diagram',
      'Data Flow',
    ];

    if (requireSecurityArchitecture) {
      sections.add('Security Architecture');
    }
    if (requirePerformanceConsiderations) {
      sections.add('Performance Considerations');
    }

    return sections;
  }
}
