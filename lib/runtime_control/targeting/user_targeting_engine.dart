import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// User targeting engine — determines if a user matches targeting criteria.
///
/// Design rationale:
/// - Supports multiple targeting dimensions: user ID, roles, segments,
///   tenant, branch, white-label client, region.
/// - Rules are evaluated in priority order — first match wins.
/// - Deterministic: same user context always produces the same result.
/// - Supports custom evaluators for complex targeting logic.
class UserTargetingEngine {
  UserTargetingEngine({
    Map<String, CustomTargetingEvaluator>? customEvaluators,
  }) : _customEvaluators = customEvaluators ?? {};

  static const String _tag = 'UserTargetingEngine';

  final Map<String, CustomTargetingEvaluator> _customEvaluators;

  /// Check if a user matches a set of targeting criteria.
  TargetingMatchResult matches({
    required List<TargetingCriterion> criteria,
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
    String? region,
    List<String>? roles,
    Set<String>? segments,
    Map<String, String>? customAttributes,
  }) {
    // Sort by priority (highest first).
    final sortedCriteria = List<TargetingCriterion>.from(criteria)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final criterion in sortedCriteria) {
      final matches = _evaluateCriterion(
        criterion,
        userId: userId,
        tenantId: tenantId,
        branchId: branchId,
        whiteLabelClient: whiteLabelClient,
        region: region,
        roles: roles,
        segments: segments,
        customAttributes: customAttributes,
      );

      if (matches) {
        AppLogger.debug(
          _tag,
          'User matched targeting criterion: ${criterion.id} '
          '(priority: ${criterion.priority})',
        );
        return TargetingMatchResult(
          matched: true,
          matchedCriterionId: criterion.id,
          matchedPriority: criterion.priority,
        );
      }
    }

    return const TargetingMatchResult(matched: false);
  }

  bool _evaluateCriterion(
    TargetingCriterion criterion, {
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
    String? region,
    List<String>? roles,
    Set<String>? segments,
    Map<String, String>? customAttributes,
  }) {
    if (criterion.userIds != null && criterion.userIds!.isNotEmpty) {
      if (userId == null || !criterion.userIds!.contains(userId)) {
        return false;
      }
    }

    if (criterion.roles != null && criterion.roles!.isNotEmpty) {
      if (roles == null || !criterion.roles!.any(roles.contains)) {
        return false;
      }
    }

    if (criterion.segments != null && criterion.segments!.isNotEmpty) {
      if (segments == null || !criterion.segments!.any(segments.contains)) {
        return false;
      }
    }

    if (criterion.tenantIds != null && criterion.tenantIds!.isNotEmpty) {
      if (tenantId == null || !criterion.tenantIds!.contains(tenantId)) {
        return false;
      }
    }

    if (criterion.branchIds != null && criterion.branchIds!.isNotEmpty) {
      if (branchId == null || !criterion.branchIds!.contains(branchId)) {
        return false;
      }
    }

    if (criterion.whiteLabelClients != null &&
        criterion.whiteLabelClients!.isNotEmpty) {
      if (whiteLabelClient == null ||
          !criterion.whiteLabelClients!.contains(whiteLabelClient)) {
        return false;
      }
    }

    if (criterion.regions != null && criterion.regions!.isNotEmpty) {
      if (region == null || !criterion.regions!.contains(region)) {
        return false;
      }
    }

    if (criterion.customEvaluatorKey != null) {
      final evaluator = _customEvaluators[criterion.customEvaluatorKey];
      if (evaluator == null) {
        AppLogger.warning(
          _tag,
          'Custom evaluator "${criterion.customEvaluatorKey}" not found.',
        );
        return false;
      }

      return evaluator.evaluate(
        parameters: criterion.customParameters ?? const {},
        customAttributes: customAttributes,
      );
    }

    return true;
  }
}

/// Targeting criterion — a single targeting rule.
class TargetingCriterion {
  const TargetingCriterion({
    required this.id,
    this.priority = 0,
    this.userIds,
    this.roles,
    this.segments,
    this.tenantIds,
    this.branchIds,
    this.whiteLabelClients,
    this.regions,
    this.customEvaluatorKey,
    this.customParameters,
  });

  final String id;
  final int priority;
  final Set<String>? userIds;
  final Set<String>? roles;
  final Set<String>? segments;
  final Set<String>? tenantIds;
  final Set<String>? branchIds;
  final Set<String>? whiteLabelClients;
  final Set<String>? regions;
  final String? customEvaluatorKey;
  final Map<String, String>? customParameters;
}

/// Result of a targeting match evaluation.
class TargetingMatchResult {
  const TargetingMatchResult({
    required this.matched,
    this.matchedCriterionId,
    this.matchedPriority,
  });

  final bool matched;
  final String? matchedCriterionId;
  final int? matchedPriority;
}

/// Custom targeting evaluator — for complex targeting logic.
abstract class CustomTargetingEvaluator {
  const CustomTargetingEvaluator();
  bool evaluate({
    required Map<String, String> parameters,
    Map<String, String>? customAttributes,
  });
}
