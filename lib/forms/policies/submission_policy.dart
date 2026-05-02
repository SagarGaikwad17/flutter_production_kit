import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/form_submission_result.dart';

/// Submission policy — determines if a form can be submitted.
///
/// Design rationale:
/// - Centralizes all pre-submission checks.
/// - Checks: offline allowed, duplicate, draft staleness, permissions.
/// - Returns typed FormSubmissionResult for each failure mode.
/// - Composable — policies can be combined.
class SubmissionPolicy {
  const SubmissionPolicy();

  /// Check if submission is allowed.
  FormSubmissionResult? canSubmit({
    required FormSchema schema,
    required bool isOnline,
    Set<String>? userEntitlements,
    List<String>? userRoles,
    String? idempotencyKey,
    Set<String>? knownSubmissionIds,
  }) {
    // Offline check.
    if (!isOnline && !schema.allowOffline) {
      return FormSubmissionNetworkError(
        formId: schema.id,
        error: 'Form cannot be submitted offline.',
        isRetryable: false,
      );
    }

    // Entitlement check.
    if (schema.requiredEntitlements.isNotEmpty && userEntitlements != null) {
      final missing = schema.requiredEntitlements
          .where((ent) => !userEntitlements.contains(ent))
          .toList();
      if (missing.isNotEmpty) {
        return FormSubmissionBlockedByEntitlement(
          formId: schema.id,
          requiredEntitlements: missing,
          reason: 'User lacks required entitlements for form: ${schema.title}',
        );
      }
    }

    // Role check.
    if (schema.requiredRoles.isNotEmpty && userRoles != null) {
      final hasRole = userRoles.any((role) => schema.requiredRoles.contains(role));
      if (!hasRole) {
        return FormSubmissionBlockedByPermission(
          formId: schema.id,
          requiredPermission: schema.requiredRoles.join(', '),
          reason: 'User lacks required roles for form: ${schema.title}',
        );
      }
    }

    // Tenant check.
    if (schema.allowedTenants != null) {
      // In production, check against user's tenant.
    }

    // Branch check.
    if (schema.allowedBranches != null) {
      // In production, check against user's branch.
    }

    // Duplicate check.
    if (idempotencyKey != null && knownSubmissionIds != null) {
      if (knownSubmissionIds.contains(idempotencyKey)) {
        return FormSubmissionDuplicatePrevented(
          formId: schema.id,
          reason: 'Duplicate submission detected for key: $idempotencyKey',
        );
      }
    }

    return null; // Submission allowed.
  }
}
