import 'package:flutter_production_kit/sdk_strategy/domain/entities/version_state.dart';

/// Semver manager — enforces semantic versioning discipline.
///
/// Design rationale:
/// - MAJOR version bumps for breaking changes.
/// - MINOR version bumps for new features (backward compatible).
/// - PATCH version bumps for bug fixes (backward compatible).
/// - Pre-release tags for alpha, beta, rc versions.
/// - Build metadata for CI/CD tracking.
///
/// Version discipline:
/// - No version can be skipped.
/// - Breaking changes MUST bump MAJOR.
/// - New features MUST bump MINOR.
/// - Bug fixes MUST bump PATCH.
/// - Pre-release versions cannot be published as stable.
class SemverManager {
  const SemverManager({
    this.requireChangelogForMajor = true,
    this.requireMigrationGuideForMajor = true,
    this.minDeprecationPeriod = const Duration(days: 180),
  });

  final bool requireChangelogForMajor;
  final bool requireMigrationGuideForMajor;
  final Duration minDeprecationPeriod;

  /// Parse a version string into a VersionState.
  VersionState parseVersion(String versionString) {
    final parts = versionString.split('+');
    final versionPart = parts[0];
    final buildMetadata = parts.length > 1 ? parts[1] : null;

    final preParts = versionPart.split('-');
    final mainPart = preParts[0];
    final prerelease = preParts.length > 1 ? preParts[1] : null;

    final mainParts = mainPart.split('.');
    if (mainParts.length != 3) {
      throw FormatException('Invalid version format: $versionString');
    }

    return VersionState(
      major: int.parse(mainParts[0]),
      minor: int.parse(mainParts[1]),
      patch: int.parse(mainParts[2]),
      prerelease: prerelease,
      buildMetadata: buildMetadata,
    );
  }

  /// Determine the appropriate version bump for a change.
  VersionResult determineBump({
    required String packageName,
    required VersionState currentVersion,
    required bool hasBreakingChanges,
    required bool hasNewFeatures,
    required bool hasBugFixes,
  }) {
    VersionState nextVersion;

    if (hasBreakingChanges) {
      nextVersion = currentVersion.bumpMajor();
    } else if (hasNewFeatures) {
      nextVersion = currentVersion.bumpMinor();
    } else if (hasBugFixes) {
      nextVersion = currentVersion.bumpPatch();
    } else {
      return VersionBumpBlocked(
        packageName: packageName,
        reason: 'No changes detected to bump version',
        currentVersion: currentVersion.versionString,
      );
    }

    return VersionBumped(
      packageName: packageName,
      previousVersion: currentVersion.versionString,
      newVersion: nextVersion.versionString,
      isBreaking: hasBreakingChanges,
      migrationGuideRequired: hasBreakingChanges && requireMigrationGuideForMajor,
    );
  }

  /// Validate a proposed version bump.
  VersionResult validateVersionBump({
    required String packageName,
    required VersionState currentVersion,
    required VersionState proposedVersion,
    required bool hasBreakingChanges,
  }) {
    // Major version must bump for breaking changes
    if (hasBreakingChanges && proposedVersion.major <= currentVersion.major) {
      return VersionBumpBlocked(
        packageName: packageName,
        reason: 'Breaking changes require MAJOR version bump',
        currentVersion: currentVersion.versionString,
        requiredAction: 'Bump MAJOR version',
      );
    }

    // No version skipping
    if (proposedVersion.major > currentVersion.major + 1) {
      return VersionBumpBlocked(
        packageName: packageName,
        reason: 'Cannot skip major versions',
        currentVersion: currentVersion.versionString,
      );
    }

    // Minor version cannot decrease
    if (proposedVersion.major == currentVersion.major &&
        proposedVersion.minor < currentVersion.minor) {
      return VersionBumpBlocked(
        packageName: packageName,
        reason: 'MINOR version cannot decrease',
        currentVersion: currentVersion.versionString,
      );
    }

    return VersionBumped(
      packageName: packageName,
      previousVersion: currentVersion.versionString,
      newVersion: proposedVersion.versionString,
      isBreaking: hasBreakingChanges,
      migrationGuideRequired: hasBreakingChanges,
    );
  }

  /// Schedule deprecation for a version.
  VersionResult scheduleDeprecation({
    required String packageName,
    required VersionState version,
    required DateTime deprecationDate,
    required DateTime endOfLifeDate,
  }) {
    final noticePeriod = endOfLifeDate.difference(deprecationDate);
    if (noticePeriod < minDeprecationPeriod) {
      return VersionBumpBlocked(
        packageName: packageName,
        reason: 'Deprecation notice period must be at least ${minDeprecationPeriod.inDays} days',
        currentVersion: version.versionString,
      );
    }

    return DeprecationScheduled(
      packageName: packageName,
      version: version.versionString,
      deprecationDate: deprecationDate,
      endOfLifeDate: endOfLifeDate,
    );
  }
}

/// Breaking change policy — manages breaking change detection and migration requirements.
class BreakingChangePolicy {
  const BreakingChangePolicy({
    this.requireMigrationGuide = true,
    this.requireChangelog = true,
    this.requireDeprecationWarning = true,
    this.minDeprecationPeriod = const Duration(days: 180),
    this.breakingChangePatterns = const [
      'remove',
      'delete',
      'rename',
      'change signature',
      'change return type',
      'change parameter type',
      'change parameter order',
      'remove parameter',
      'add required parameter',
      'change class inheritance',
      'change enum values',
    ],
  });

  final bool requireMigrationGuide;
  final bool requireChangelog;
  final bool requireDeprecationWarning;
  final Duration minDeprecationPeriod;
  final List<String> breakingChangePatterns;

  /// Detect if a change is breaking.
  bool isBreakingChange(String changeDescription) {
    final lower = changeDescription.toLowerCase();
    return breakingChangePatterns.any((pattern) => lower.contains(pattern));
  }

  /// Validate that a breaking change has proper migration support.
  bool validateBreakingChange({
    required String changeDescription,
    required bool hasMigrationGuide,
    required bool hasChangelog,
    required bool hasDeprecationWarning,
  }) {
    if (!isBreakingChange(changeDescription)) return true;

    if (requireMigrationGuide && !hasMigrationGuide) return false;
    if (requireChangelog && !hasChangelog) return false;
    if (requireDeprecationWarning && !hasDeprecationWarning) return false;

    return true;
  }
}
