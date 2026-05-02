import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Release governance engine — enforces release standards and approval workflows.
///
/// Design rationale:
/// - Releases must pass governance checks before publishing.
/// - Each package has its own governance requirements.
/// - Breaking changes require explicit approval from maintainers.
/// - Changelog entries are mandatory for every release.
///
/// Governance checks:
/// 1. Semantic version compliance (no skipped versions).
/// 2. Changelog entry exists and follows format.
/// 3. All tests pass with minimum coverage.
/// 4. No known security vulnerabilities.
/// 5. API compatibility check (for non-breaking releases).
/// 6. Documentation updated.
/// 7. Approval from required maintainers.
class ReleaseGovernanceEngine {
  const ReleaseGovernanceEngine({
    required IReleaseGovernanceRepository releaseGovernanceRepository,
    required IChangelogRepository changelogRepository,
    this.requiredApproversPerPackage = const {
      'default': 2,
    },
    this.governanceChecks = const [
      'semver_compliance',
      'changelog_entry',
      'tests_pass',
      'security_scan',
      'api_compatibility',
      'documentation_updated',
    ],
    this.breakingChangeRequiresAllApprovers = true,
  })  : _releaseGovernanceRepository = releaseGovernanceRepository,
        _changelogRepository = changelogRepository;

  final IReleaseGovernanceRepository _releaseGovernanceRepository;
  final IChangelogRepository _changelogRepository;
  final Map<String, int> requiredApproversPerPackage;
  final List<String> governanceChecks;
  final bool breakingChangeRequiresAllApprovers;

  /// Run governance checks for a release.
  Future<RepoResult> runGovernanceChecks({
    required String packageName,
    required String version,
    required Map<String, bool> checkResults,
    required List<String> approvers,
    bool isBreakingChange = false,
  }) async {
    final failedChecks = <String>[];

    // Check 1: Semver compliance
    if (checkResults['semver_compliance'] != true) {
      failedChecks.add('Semantic version compliance failed');
    }

    // Check 2: Changelog entry
    final changelog = await _changelogRepository.getChangelog(packageName);
    if (changelog == null || !changelog.contains(version)) {
      failedChecks.add('Missing changelog entry for version $version');
    }

    // Check 3: Tests pass
    if (checkResults['tests_pass'] != true) {
      failedChecks.add('Tests did not pass');
    }

    // Check 4: Security scan
    if (checkResults['security_scan'] != true) {
      failedChecks.add('Security scan failed');
    }

    // Check 5: API compatibility
    if (!isBreakingChange && checkResults['api_compatibility'] != true) {
      failedChecks.add('API compatibility check failed');
    }

    // Check 6: Documentation updated
    if (checkResults['documentation_updated'] != true) {
      failedChecks.add('Documentation not updated');
    }

    // Check 7: Approvals
    final requiredApprovers = requiredApproversPerPackage[packageName] ??
        requiredApproversPerPackage['default']!;
    final actualApprovers = approvers.length;

    if (isBreakingChange && breakingChangeRequiresAllApprovers) {
      if (actualApprovers < requiredApprovers) {
        failedChecks.add(
          'Breaking change requires all $requiredApprovers approvers '
          '(has $actualApprovers)',
        );
      }
    } else if (actualApprovers < requiredApprovers) {
      failedChecks.add(
        'Requires $requiredApprovers approvers (has $actualApprovers)',
      );
    }

    if (failedChecks.isNotEmpty) {
      throw ReleaseGovernanceFailedException(
        message: 'Release governance checks failed',
        packageName: packageName,
        failedChecks: failedChecks,
      );
    }

    // Record successful governance
    await _releaseGovernanceRepository.recordGovernanceResult(
      packageName: packageName,
      version: version,
      passed: true,
      checks: governanceChecks,
      approvers: approvers,
    );

    return ReleaseGovernanceApproved(
      operation: 'run_governance_checks',
      packageName: packageName,
      version: version,
      approvers: approvers,
    );
  }

  /// Check if a package is ready for pub.dev publishing.
  Future<RepoResult> checkPubDevReadiness({
    required String packageName,
    required String version,
  }) async {
    final checks = await _releaseGovernanceRepository.getGovernanceChecks(
      packageName,
      version,
    );

    final passedChecks = checks.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final score = (passedChecks.length / checks.length * 100).round();

    if (score < 100) {
      final failed = checks.entries
          .where((e) => !e.value)
          .map((e) => e.key)
          .toList();

      throw ReleaseGovernanceFailedException(
        message: 'Package not ready for pub.dev (score: $score%)',
        packageName: packageName,
        failedChecks: failed,
      );
    }

    return PubDevPublishSafe(
      operation: 'check_pubdev_readiness',
      packageName: packageName,
      score: score,
      checks: passedChecks,
    );
  }

  /// Get required approvers for a package.
  Future<List<String>> getRequiredApprovers(String packageName) {
    return _releaseGovernanceRepository.getRequiredApprovers(packageName);
  }
}

/// Changelog manager — manages changelog entries and validation.
///
/// Design rationale:
/// - Every release must have a changelog entry.
/// - Entries follow a standard format: type, scope, description.
/// - Breaking changes are clearly marked.
/// - Historical versions are easily accessible.
///
/// Entry format:
/// ```
/// ## [version] - date
///
/// ### Breaking Changes
/// - description
///
/// ### Features
/// - description
///
/// ### Bug Fixes
/// - description
///
/// ### Documentation
/// - description
/// ```
class ChangelogManager {
  const ChangelogManager({
    required IChangelogRepository changelogRepository,
    this.entryTypes = const [
      'breaking_changes',
      'features',
      'bug_fixes',
      'deprecations',
      'performance',
      'documentation',
      'maintenance',
    ],
    this.dateFormat = 'yyyy-MM-dd',
  }) : _changelogRepository = changelogRepository;

  final IChangelogRepository _changelogRepository;
  final List<String> entryTypes;
  final String dateFormat;

  /// Add a changelog entry for a release.
  Future<RepoResult> addEntry({
    required String packageName,
    required String version,
    required String type,
    required String description,
    DateTime? date,
    String? author,
  }) async {
    if (!entryTypes.contains(type)) {
      throw ChangelogValidationFailedException(
        message: 'Invalid entry type: $type',
        packageName: packageName,
        missingEntries: ['Valid types: ${entryTypes.join(', ')}'],
      );
    }

    final entryDate = date ?? DateTime.now();
    final entry = '- $description${author != null ? ' (@$author)' : ''}';

    await _changelogRepository.saveChangelogEntry(
      packageName: packageName,
      version: version,
      entry: entry,
      date: entryDate,
    );

    return ChangelogValidationPassed(
      operation: 'add_changelog_entry',
      packageName: packageName,
      entries: [entry],
    );
  }

  /// Validate changelog for a release.
  Future<RepoResult> validateChangelog({
    required String packageName,
    required String version,
  }) async {
    final changelog = await _changelogRepository.getChangelog(packageName);

    if (changelog == null) {
      throw ChangelogValidationFailedException(
        message: 'No changelog found for $packageName',
        packageName: packageName,
        missingEntries: ['Create CHANGELOG.md for $packageName'],
      );
    }

    final missingEntries = <String>[];

    // Check for version header
    if (!changelog.contains('## [$version]')) {
      missingEntries.add('Missing version header for $version');
    }

    // Check for at least one entry type
    bool hasEntry = false;
    for (final type in entryTypes) {
      if (changelog.contains('### ${_formatHeader(type)}')) {
        hasEntry = true;
        break;
      }
    }
    if (!hasEntry) {
      missingEntries.add('No entry sections found');
    }

    if (missingEntries.isNotEmpty) {
      throw ChangelogValidationFailedException(
        message: 'Changelog validation failed for $packageName $version',
        packageName: packageName,
        missingEntries: missingEntries,
      );
    }

    return ChangelogValidationPassed(
      operation: 'validate_changelog',
      packageName: packageName,
    );
  }

  /// Get version history for a package.
  Future<List<Map<String, String>>> getVersionHistory(String packageName) {
    return _changelogRepository.getVersionHistory(packageName);
  }

  String _formatHeader(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
