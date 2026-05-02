import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';

/// README trust framework — evaluates and optimizes README for trust signals.
///
/// Design rationale:
/// - README is the first impression for contributors and users.
/// - Trust signals increase adoption and contributor confidence.
/// - Score-based evaluation identifies gaps and improvement areas.
///
/// Trust signals:
/// 1. Clear project description and purpose.
/// 2. Quick start guide (5-minute setup).
/// 3. Architecture overview and design principles.
/// 4. Contribution guidelines.
/// 5. Code of conduct.
/// 6. License (Apache 2.0, MIT, etc.).
/// 7. Badge collection (build, coverage, license, version).
/// 8. Security policy.
/// 9. Release notes / changelog link.
/// 10. Community links (Discord, GitHub Discussions).
/// 11. Sponsors / funding transparency.
/// 12. Maintainer team information.
class READMETrustFramework {
  const READMETrustFramework({
    this.trustSignals = const {
      'description': 10,
      'quick_start': 15,
      'architecture': 10,
      'contribution_guide': 10,
      'code_of_conduct': 5,
      'license': 10,
      'badges': 10,
      'security_policy': 5,
      'release_notes': 5,
      'community_links': 5,
      'sponsors': 5,
      'maintainer_info': 10,
    },
    this.minimumScore = 70,
  });

  final Map<String, int> trustSignals;
  final int minimumScore;

  /// Evaluate a README against trust signals.
  Future<RepoResult> evaluateReadme({
    required String content,
    required Map<String, bool> presentSignals,
  }) async {
    int score = 0;
    int maxScore = 0;
    final missing = <String>[];
    final present = <String>[];

    for (final entry in trustSignals.entries) {
      maxScore += entry.value;
      if (presentSignals[entry.key] == true) {
        score += entry.value;
        present.add(entry.key);
      } else {
        missing.add(entry.key);
      }
    }

    final normalizedScore = (score / maxScore * 100).round();

    if (normalizedScore < minimumScore) {
      return MaintainerOverloadRiskDetected(
        operation: 'evaluate_readme',
        riskLevel: 'low_trust',
        indicators: [
          'Trust score: $normalizedScore% (minimum: $minimumScore%)',
          'Missing signals: ${missing.join(', ')}',
        ],
        recommendations: missing.map((m) => _getRecommendation(m)).toList(),
      );
    }

    return RepositoryLaunchValidated(
      operation: 'evaluate_readme',
      checks: present.map((p) => 'Present: $p').toList(),
      warnings: missing.map((m) => 'Missing: $m').toList(),
    );
  }

  /// Generate a trust score for a README.
  int calculateTrustScore(Map<String, bool> presentSignals) {
    int score = 0;
    int maxScore = 0;

    for (final entry in trustSignals.entries) {
      maxScore += entry.value;
      if (presentSignals[entry.key] == true) {
        score += entry.value;
      }
    }

    return (score / maxScore * 100).round();
  }

  /// Generate recommendations for improving README trust.
  List<String> generateRecommendations(Map<String, bool> presentSignals) {
    final recommendations = <String>[];

    for (final entry in trustSignals.entries) {
      if (presentSignals[entry.key] != true) {
        recommendations.add(_getRecommendation(entry.key));
      }
    }

    return recommendations;
  }

  /// Generate a recommended README structure.
  String generateRecommendedStructure() {
    return '''
# Project Name

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-85%25-brightgreen)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)]()
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()

## Description

A clear and concise description of what this project does and why it exists.

## Quick Start

```bash
flutter pub add package_name
```

```dart
import 'package:package_name/package_name.dart';

void main() {
  // Example usage
}
```

## Architecture

Overview of the architecture and design principles.

## Features

- Feature 1
- Feature 2
- Feature 3

## Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md).

## Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md).

## Security

Please read our [Security Policy](SECURITY.md).

## License

This project is licensed under the Apache 2.0 License. See [LICENSE](LICENSE) for details.

## Community

- [GitHub Discussions](https://github.com/org/repo/discussions)
- [Discord](https://discord.gg/invite)

## Sponsors

Thank you to our sponsors! [Become a sponsor](https://github.com/sponsors/org)

## Maintainers

- [@maintainer1](https://github.com/maintainer1)
- [@maintainer2](https://github.com/maintainer2)
''';
  }

  String _getRecommendation(String signal) {
    switch (signal) {
      case 'description':
        return 'Add a clear project description at the top of README';
      case 'quick_start':
        return 'Add a quick start guide with code examples';
      case 'architecture':
        return 'Add an architecture overview section';
      case 'contribution_guide':
        return 'Link to CONTRIBUTING.md with clear contribution guidelines';
      case 'code_of_conduct':
        return 'Add a code of conduct link';
      case 'license':
        return 'Add license badge and information';
      case 'badges':
        return 'Add status badges (build, coverage, license, version)';
      case 'security_policy':
        return 'Add a security policy and link to SECURITY.md';
      case 'release_notes':
        return 'Link to CHANGELOG.md or release notes';
      case 'community_links':
        return 'Add community links (Discord, Discussions, etc.)';
      case 'sponsors':
        return 'Add sponsor information and funding transparency';
      case 'maintainer_info':
        return 'Add maintainer team information';
      default:
        return 'Improve README section: $signal';
    }
  }
}
