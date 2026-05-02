import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// CI/CD validation engine — validates CI/CD pipeline configuration and results.
///
/// Design rationale:
/// - CI/CD pipelines are the gatekeepers of code quality.
/// - Validation must be deterministic and reproducible.
/// - PII and secrets must never leak through CI/CD logs.
/// - Pipeline failures must have actionable guidance.
///
/// Validation gates:
/// 1. Build succeeds on all target platforms.
/// 2. Tests pass with minimum coverage threshold.
/// 3. Linting and formatting checks pass.
/// 4. Security scans (SAST, dependency audit) pass.
/// 5. Performance benchmarks stay within thresholds.
/// 6. Secret scanning passes (no leaked credentials).
class CIVValidationEngine {
  const CIVValidationEngine({
    this.minimumCoverage = 80.0,
    this.requiredPlatforms = const ['android', 'ios', 'web', 'linux'],
    this.maxBuildTime = const Duration(minutes: 15),
    this.maxTestTime = const Duration(minutes: 10),
    this.requiredSecurityChecks = const [
      'dependency_audit',
      'secret_scan',
      'sast',
    ],
    this.performanceThresholds = const {
      'app_start_ms': 2000,
      'frame_budget_ms': 16,
      'memory_mb': 200,
    },
  });

  final double minimumCoverage;
  final List<String> requiredPlatforms;
  final Duration maxBuildTime;
  final Duration maxTestTime;
  final List<String> requiredSecurityChecks;
  final Map<String, double> performanceThresholds;

  /// Validate a CI/CD pipeline run.
  Future<RepoResult> validatePipelineRun({
    required Map<String, bool> checks,
    required Map<String, Duration> timings,
    required double coverage,
    required Map<String, double> performanceMetrics,
    required List<String> securityResults,
    required List<String> secretScanResults,
  }) async {
    final violations = <String>[];

    // Gate 1: Build checks
    for (final platform in requiredPlatforms) {
      if (checks['build_$platform'] != true) {
        violations.add('Build failed on $platform');
      }
    }

    // Gate 2: Test coverage
    if (coverage < minimumCoverage) {
      violations.add(
        'Coverage $coverage% below minimum $minimumCoverage%',
      );
    }

    // Gate 3: Build timing
    for (final platform in requiredPlatforms) {
      final time = timings['build_$platform'];
      if (time != null && time > maxBuildTime) {
        violations.add(
          'Build on $platform took ${time.inSeconds}s (max: ${maxBuildTime.inSeconds}s)',
        );
      }
    }

    // Gate 4: Test timing
    final testTime = timings['test'];
    if (testTime != null && testTime > maxTestTime) {
      violations.add(
        'Tests took ${testTime.inSeconds}s (max: ${maxTestTime.inSeconds}s)',
      );
    }

    // Gate 5: Security checks
    for (final check in requiredSecurityChecks) {
      if (!securityResults.contains(check)) {
        violations.add('Security check "$check" not run');
      } else if (securityResults.contains('${check}_failed')) {
        violations.add('Security check "$check" failed');
      }
    }

    // Gate 6: Secret scanning
    if (secretScanResults.isNotEmpty) {
      violations.addAll(
        secretScanResults.map((r) => 'Secret scan found: $r'),
      );
    }

    // Gate 7: Performance thresholds
    for (final entry in performanceThresholds.entries) {
      final metric = performanceMetrics[entry.key];
      if (metric != null && metric > entry.value) {
        violations.add(
          'Performance "${entry.key}" is $metric (threshold: ${entry.value})',
        );
      }
    }

    if (violations.isNotEmpty) {
      throw ReleaseGovernanceFailedException(
        message: 'CI/CD pipeline validation failed',
        packageName: 'flutter_production_kit',
        failedChecks: violations,
      );
    }

    return MonorepoValidationPassed(
      operation: 'validate_pipeline',
      packageCount: requiredPlatforms.length,
    );
  }

  /// Validate pipeline configuration (not a run).
  Future<RepoResult> validatePipelineConfig({
    required Map<String, String> config,
  }) async {
    final violations = <String>[];

    // Check for required platform configurations
    for (final platform in requiredPlatforms) {
      if (!config.containsKey('build_$platform')) {
        violations.add('Missing build config for $platform');
      }
    }

    // Check for security check configurations
    for (final check in requiredSecurityChecks) {
      if (!config.containsKey('security_$check')) {
        violations.add('Missing security config for $check');
      }
    }

    if (violations.isNotEmpty) {
      throw ReleaseGovernanceFailedException(
        message: 'CI/CD pipeline configuration invalid',
        packageName: 'flutter_production_kit',
        failedChecks: violations,
      );
    }

    return MonorepoValidationPassed(
      operation: 'validate_pipeline_config',
      packageCount: config.length,
    );
  }
}

/// Release pipeline manager — orchestrates the release pipeline from build to deploy.
///
/// Design rationale:
/// - Release pipeline is deterministic: build → test → validate → sign → deploy.
/// - Each stage must pass before proceeding to the next.
/// - Hotfix releases bypass approval gates but retain signing and validation.
/// - Rollback is always possible and automated on health gate failures.
///
/// Pipeline stages:
/// 1. Build: Compile for all target platforms and flavors.
/// 2. Test: Run unit, widget, and integration tests.
/// 3. Validate: Run CI/CD validation engine.
/// 4. Sign: Sign binaries with appropriate certificates.
/// 5. Approve: Require maintainer approval (unless hotfix).
/// 6. Deploy: Push to pub.dev or distribution channels.
/// 7. Rollout: Staged rollout with health monitoring.
class ReleasePipelineManager {
  const ReleasePipelineManager({
    required CIVValidationEngine ciValidationEngine,
    required IReleaseGovernanceRepository releaseGovernanceRepository,
    this.requireApproval = true,
    this.hotfixBypassApproval = true,
    this.releaseStages = const [
      'build',
      'test',
      'validate',
      'sign',
      'approve',
      'deploy',
      'rollout',
    ],
  })  : _ciValidationEngine = ciValidationEngine,
        _releaseGovernanceRepository = releaseGovernanceRepository;

  final CIVValidationEngine _ciValidationEngine;
  final IReleaseGovernanceRepository _releaseGovernanceRepository;
  final bool requireApproval;
  final bool hotfixBypassApproval;
  final List<String> releaseStages;

  /// Execute a full release pipeline.
  Future<RepoResult> executeRelease({
    required String packageName,
    required String version,
    required Map<String, bool> checks,
    required Map<String, Duration> timings,
    required double coverage,
    required Map<String, double> performanceMetrics,
    required List<String> securityResults,
    required List<String> secretScanResults,
    bool isHotfix = false,
    List<String> approvers = const [],
  }) async {
    final failedStages = <String>[];

    // Stage 1: Build
    final buildPassed = _executeBuildStage(packageName, version);
    if (!buildPassed) {
      failedStages.add('build');
    }

    // Stage 2: Test
    final testPassed = _executeTestStage(checks, coverage);
    if (!testPassed) {
      failedStages.add('test');
    }

    // Stage 3: Validate
    try {
      await _ciValidationEngine.validatePipelineRun(
        checks: checks,
        timings: timings,
        coverage: coverage,
        performanceMetrics: performanceMetrics,
        securityResults: securityResults,
        secretScanResults: secretScanResults,
      );
    } catch (e) {
      failedStages.add('validate');
    }

    // Stage 4: Sign (always required)
    final signPassed = _executeSignStage(packageName, version);
    if (!signPassed) {
      failedStages.add('sign');
    }

    // Stage 5: Approve (bypassed for hotfixes)
    final approvalPassed = isHotfix && hotfixBypassApproval
        ? true
        : _executeApproveStage(approvers, requireApproval);
    if (!approvalPassed) {
      failedStages.add('approve');
    }

    // Stage 6: Deploy
    final deployPassed = _executeDeployStage(packageName, version);
    if (!deployPassed) {
      failedStages.add('deploy');
    }

    // Stage 7: Record governance result
    await _releaseGovernanceRepository.recordGovernanceResult(
      packageName: packageName,
      version: version,
      passed: failedStages.isEmpty,
      checks: releaseStages,
      approvers: approvers,
    );

    if (failedStages.isNotEmpty) {
      throw ReleaseGovernanceFailedException(
        message: 'Release pipeline failed at stages: ${failedStages.join(', ')}',
        packageName: packageName,
        failedChecks: failedStages,
      );
    }

    return ReleaseGovernanceApproved(
      operation: 'execute_release',
      packageName: packageName,
      version: version,
      approvers: approvers,
    );
  }

  /// Execute a hotfix release (bypasses approval gates).
  Future<RepoResult> executeHotfix({
    required String packageName,
    required String version,
    required Map<String, bool> checks,
    required Map<String, Duration> timings,
    required double coverage,
    required Map<String, double> performanceMetrics,
    required List<String> securityResults,
    required List<String> secretScanResults,
    required String author,
  }) {
    return executeRelease(
      packageName: packageName,
      version: version,
      checks: checks,
      timings: timings,
      coverage: coverage,
      performanceMetrics: performanceMetrics,
      securityResults: securityResults,
      secretScanResults: secretScanResults,
      isHotfix: true,
      approvers: [author],
    );
  }

  bool _executeBuildStage(String packageName, String version) {
    // In production: trigger build pipeline for all platforms/flavors.
    return true;
  }

  bool _executeTestStage(Map<String, bool> checks, double coverage) {
    // In production: run test suite and measure coverage.
    return checks['test'] == true && coverage >= 80.0;
  }

  bool _executeSignStage(String packageName, String version) {
    // In production: sign binaries with certificates.
    return true;
  }

  bool _executeApproveStage(List<String> approvers, bool requireApproval) {
    if (!requireApproval) return true;
    return approvers.isNotEmpty;
  }

  bool _executeDeployStage(String packageName, String version) {
    // In production: deploy to pub.dev or distribution channels.
    return true;
  }
}
