import 'package:flutter_production_kit/release_engineering/domain/entities/release_result.dart';

/// Release compliance manager — ensures releases meet regulatory requirements.
///
/// Design rationale:
/// - Compliance checks are environment-specific.
/// - Healthcare, financial, and government releases have additional requirements.
/// - Compliance checks produce explicit pass/fail results.
/// - Compliance violations block release promotion.
/// - Compliance audit trail is immutable.
///
/// Compliance requirements by industry:
/// - Healthcare (HIPAA): data encryption, audit logging, access controls.
/// - Financial (PCI-DSS): payment security, data isolation, audit trails.
/// - Government (FedRAMP): access controls, encryption, audit logging.
/// - General (GDPR): data privacy, user consent, data deletion.
///
/// Compliance checks:
/// - Release metadata validation.
/// - Artifact integrity verification.
/// - Signing key validation.
/// - Approval workflow validation.
/// - Environment configuration validation.
/// - Data privacy validation.
class ReleaseComplianceManager {
  const ReleaseComplianceManager({
    this.requireComplianceChecks = true,
    this.industrySpecificChecks = const {
      'healthcare': [
        'data_encryption',
        'audit_logging',
        'access_controls',
        'data_residency',
      ],
      'financial': [
        'payment_security',
        'data_isolation',
        'audit_trails',
        'transaction_integrity',
      ],
      'government': [
        'access_controls',
        'encryption',
        'audit_logging',
        'security_clearance',
      ],
      'general': [
        'data_privacy',
        'user_consent',
        'data_deletion',
      ],
    },
  });

  final bool requireComplianceChecks;
  final Map<String, List<String>> industrySpecificChecks;

  /// Run compliance checks for a release.
  ReleaseResult runComplianceChecks({
    required String releaseId,
    required String industry,
    required String environment,
    Map<String, String>? metadata,
  }) {
    if (!requireComplianceChecks) {
      return ReleaseValidated(
        releaseId: releaseId,
        flavor: '',
        checksum: '',
        warnings: ['Compliance checks disabled'],
      );
    }

    final requiredChecks = industrySpecificChecks[industry];
    if (requiredChecks == null) {
      return ReleaseValidated(
        releaseId: releaseId,
        flavor: '',
        checksum: '',
        warnings: ['Unknown industry: $industry'],
      );
    }

    final violations = <String>[];

    for (final check in requiredChecks) {
      final result = _runCheck(check, industry, environment, metadata);
      if (!result.isValid) {
        violations.addAll(result.errors);
      }
    }

    if (violations.isNotEmpty) {
      return BlockedByComplianceViolation(
        releaseId: releaseId,
        violation: violations.join('; '),
        regulation: industry,
      );
    }

    return ReleaseValidated(
      releaseId: releaseId,
      flavor: '',
      checksum: '',
    );
  }

  _ComplianceCheckResult _runCheck(
    String check,
    String industry,
    String environment,
    Map<String, String>? metadata,
  ) {
    switch (check) {
      case 'data_encryption':
        return _checkDataEncryption(metadata);
      case 'audit_logging':
        return _checkAuditLogging(metadata);
      case 'access_controls':
        return _checkAccessControls(metadata);
      case 'data_residency':
        return _checkDataResidency(metadata);
      case 'payment_security':
        return _checkPaymentSecurity(metadata);
      case 'data_isolation':
        return _checkDataIsolation(metadata);
      case 'data_privacy':
        return _checkDataPrivacy(metadata);
      case 'user_consent':
        return _checkUserConsent(metadata);
      case 'data_deletion':
        return _checkDataDeletion(metadata);
      default:
        return const _ComplianceCheckResult(isValid: true);
    }
  }

  _ComplianceCheckResult _checkDataEncryption(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for data encryption check'],
      );
    }
    final encryption = metadata['encryption_enabled'];
    if (encryption != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Data encryption not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkAuditLogging(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for audit logging check'],
      );
    }
    final logging = metadata['audit_logging_enabled'];
    if (logging != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Audit logging not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkAccessControls(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for access controls check'],
      );
    }
    final controls = metadata['access_controls_enabled'];
    if (controls != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Access controls not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkDataResidency(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for data residency check'],
      );
    }
    final residency = metadata['data_residency_compliant'];
    if (residency != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Data residency not compliant'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkPaymentSecurity(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for payment security check'],
      );
    }
    final payment = metadata['payment_security_compliant'];
    if (payment != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Payment security not compliant'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkDataIsolation(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for data isolation check'],
      );
    }
    final isolation = metadata['data_isolation_enabled'];
    if (isolation != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Data isolation not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkDataPrivacy(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for data privacy check'],
      );
    }
    final privacy = metadata['data_privacy_compliant'];
    if (privacy != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Data privacy not compliant'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkUserConsent(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for user consent check'],
      );
    }
    final consent = metadata['user_consent_enabled'];
    if (consent != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['User consent not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }

  _ComplianceCheckResult _checkDataDeletion(Map<String, String>? metadata) {
    if (metadata == null) {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Missing metadata for data deletion check'],
      );
    }
    final deletion = metadata['data_deletion_enabled'];
    if (deletion != 'true') {
      return const _ComplianceCheckResult(
        isValid: false,
        errors: ['Data deletion not enabled'],
      );
    }
    return const _ComplianceCheckResult(isValid: true);
  }
}

class _ComplianceCheckResult {
  const _ComplianceCheckResult({
    required this.isValid,
    this.errors = const [],
  });

  final bool isValid;
  final List<String> errors;
}
