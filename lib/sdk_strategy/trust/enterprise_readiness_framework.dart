import 'package:flutter_production_kit/sdk_strategy/domain/entities/adoption_metric.dart';
import 'package:flutter_production_kit/sdk_strategy/domain/exceptions/sdk_exception.dart';

/// Enterprise readiness framework — evaluates package readiness for enterprise adoption.
///
/// Design rationale:
/// - Enterprise customers need proof of production readiness.
/// - Readiness is evaluated across multiple dimensions.
/// - Certification is granted when all checks pass.
/// - Audit reports provide evidence of readiness.
///
/// Readiness dimensions:
/// - Production readiness — stable API, no breaking changes without notice.
/// - Security posture — security audit, vulnerability management.
/// - Maintenance guarantees — active maintainers, release cadence.
/// - Support guarantees — issue response time, SLA.
/// - Compliance — regulatory compliance documentation.
/// - Scalability — performance benchmarks, load testing.
/// - Integration — compatibility with enterprise systems.
class EnterpriseReadinessFramework {
  const EnterpriseReadinessFramework({
    this.minimumOverallScore = 0.90,
    this.requiredCertifications = const [
      'security_audit',
      'production_readiness',
      'maintenance_guarantee',
    ],
    this.enterpriseChecks = const {
      'production_readiness': [
        'stable_api',
        'no_unannounced_breaking_changes',
        'backward_compatible_minor_releases',
        'lts_version_available',
        'production_case_studies',
      ],
      'security_posture': [
        'security_audit_completed',
        'vulnerability_disclosure_policy',
        'dependency_vulnerability_monitoring',
        'secure_coding_standards',
        'penetration_test_completed',
      ],
      'maintenance_guarantees': [
        'active_maintainers',
        'regular_release_cadence',
        'deprecation_policy',
        'end_of_life_policy',
        'backport_policy',
      ],
      'support_guarantees': [
        'issue_response_sla',
        'bug_fix_sla',
        'security_fix_sla',
        'documentation_currency',
        'migration_support',
      ],
      'compliance': [
        'gdpr_compliance',
        'data_privacy_documentation',
        'audit_trail_support',
        'access_control_documentation',
      ],
      'scalability': [
        'performance_benchmarks',
        'load_test_results',
        'memory_usage_profile',
        'startup_time_profile',
      ],
    },
  });

  final double minimumOverallScore;
  final List<String> requiredCertifications;
  final Map<String, List<String>> enterpriseChecks;

  /// Evaluate enterprise readiness for a package.
  ReadinessResult evaluateReadiness({
    required String packageName,
    required Map<String, bool> checkResults,
    List<String>? certifications,
    String? auditReportUrl,
  }) {
    final failedChecks = <String>[];
    var passedCount = 0;
    var totalCount = 0;

    for (final entry in enterpriseChecks.entries) {
      for (final check in entry.value) {
        totalCount++;
        final key = '${entry.key}.$check';
        if (checkResults[key] == true) {
          passedCount++;
        } else {
          failedChecks.add(check);
        }
      }
    }

    final score = totalCount > 0 ? passedCount / totalCount : 0.0;

    if (failedChecks.isNotEmpty) {
      return EnterpriseReadinessFailed(
        packageName: packageName,
        failedChecks: failedChecks,
        recommendedActions: [
          'Address failed checks before claiming enterprise readiness',
          'Complete security audit if not done',
          'Publish production case studies',
        ],
      );
    }

    if (score < minimumOverallScore) {
      throw EnterpriseReadinessFailureException(
        message: 'Enterprise readiness score $score below minimum $minimumOverallScore',
        packageName: packageName,
        failedChecks: failedChecks,
      );
    }

    final trustScore = TrustScore(
      packageName: packageName,
      overallScore: score,
      documentationScore: _calculateSubScore(checkResults, 'documentation'),
      stabilityScore: _calculateSubScore(checkResults, 'production_readiness'),
      securityScore: _calculateSubScore(checkResults, 'security_posture'),
      maintainerScore: _calculateSubScore(checkResults, 'maintenance_guarantees'),
      communityScore: _calculateSubScore(checkResults, 'support_guarantees'),
      enterpriseReady: true,
      certifications: certifications ?? requiredCertifications,
      lastAuditDate: DateTime.now(),
    );

    return EnterpriseReadinessCertified(
      packageName: packageName,
      trustScore: trustScore,
      certifications: certifications ?? requiredCertifications,
      auditReportUrl: auditReportUrl,
    );
  }

  double _calculateSubScore(Map<String, bool> results, String category) {
    final checks = enterpriseChecks[category];
    if (checks == null) return 0.0;

    var passed = 0;
    for (final check in checks) {
      if (results['$category.$check'] == true) {
        passed++;
      }
    }

    return checks.isEmpty ? 0.0 : passed / checks.length;
  }
}
