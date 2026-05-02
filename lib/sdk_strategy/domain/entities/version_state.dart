/// Version state — represents a package version with semantic versioning metadata.
///
/// Design rationale:
/// - Semantic versioning: MAJOR.MINOR.PATCH
/// - MAJOR: breaking changes
/// - MINOR: new features (backward compatible)
/// - PATCH: bug fixes (backward compatible)
/// - Pre-release: alpha, beta, rc tags
/// - Build metadata: +build.number
///
/// Version lifecycle:
///   drafted → validated → published → supported → deprecated → archived
class VersionState {
  const VersionState({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.buildMetadata,
    this.packageName = '',
    this.releaseDate,
    this.isBreaking = false,
    this.deprecationDate,
    this.endOfLifeDate,
    this.ltsUntil,
    this.migrationGuideUrl,
    this.changelogUrl,
  });

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;
  final String? buildMetadata;
  final String packageName;
  final DateTime? releaseDate;
  final bool isBreaking;
  final DateTime? deprecationDate;
  final DateTime? endOfLifeDate;
  final DateTime? ltsUntil;
  final String? migrationGuideUrl;
  final String? changelogUrl;

  String get versionString {
    var base = '$major.$minor.$patch';
    if (prerelease != null && prerelease!.isNotEmpty) {
      base = '$base-$prerelease';
    }
    if (buildMetadata != null && buildMetadata!.isNotEmpty) {
      base = '$base+$buildMetadata';
    }
    return base;
  }

  bool get isStable => prerelease == null;
  bool get isPreRelease => prerelease != null;
  bool get isDeprecated => deprecationDate != null;
  bool get isEndOfLife =>
      endOfLifeDate != null && DateTime.now().isAfter(endOfLifeDate!);
  bool get isLts => ltsUntil != null && DateTime.now().isBefore(ltsUntil!);

  VersionState bumpMajor() {
    return VersionState(
      major: major + 1,
      minor: 0,
      patch: 0,
      packageName: packageName,
      isBreaking: true,
    );
  }

  VersionState bumpMinor() {
    return VersionState(
      major: major,
      minor: minor + 1,
      patch: 0,
      packageName: packageName,
    );
  }

  VersionState bumpPatch() {
    return VersionState(
      major: major,
      minor: minor,
      patch: patch + 1,
      packageName: packageName,
    );
  }

  VersionState withPrerelease(String tag) {
    return VersionState(
      major: major,
      minor: minor,
      patch: patch,
      prerelease: tag,
      packageName: packageName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VersionState &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        other.prerelease == prerelease;
  }

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, prerelease);

  int compareTo(VersionState other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (prerelease == null && other.prerelease != null) return 1;
    if (prerelease != null && other.prerelease == null) return -1;
    if (prerelease != null && other.prerelease != null) {
      return prerelease!.compareTo(other.prerelease!);
    }
    return 0;
  }
}

/// Version result — outcome of a version operation.
sealed class VersionResult {
  const VersionResult({required this.packageName});
  final String packageName;

  bool get isSuccess => this is VersionBumped;
}

/// Version successfully bumped.
final class VersionBumped extends VersionResult {
  const VersionBumped({
    required super.packageName,
    required this.previousVersion,
    required this.newVersion,
    this.isBreaking = false,
    this.migrationGuideRequired = false,
  });
  final String previousVersion;
  final String newVersion;
  final bool isBreaking;
  final bool migrationGuideRequired;
}

/// Version bump blocked by breaking change policy.
final class VersionBumpBlocked extends VersionResult {
  const VersionBumpBlocked({
    required super.packageName,
    required this.reason,
    this.currentVersion,
    this.requiredAction,
  });
  final String reason;
  final String? currentVersion;
  final String? requiredAction;
}

/// Deprecation scheduled.
final class DeprecationScheduled extends VersionResult {
  const DeprecationScheduled({
    required super.packageName,
    required this.version,
    required this.deprecationDate,
    required this.endOfLifeDate,
    this.migrationGuideUrl,
  });
  final String version;
  final DateTime deprecationDate;
  final DateTime endOfLifeDate;
  final String? migrationGuideUrl;
}
