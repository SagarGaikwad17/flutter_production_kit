import 'package:flutter_production_kit/forms/domain/entities/form_schema.dart';
import 'package:flutter_production_kit/forms/domain/entities/workflow_step.dart';

/// Step transition manager — evaluates transition rules for workflow steps.
///
/// Design rationale:
/// - Evaluates transition rules in order.
/// - Returns the target step ID if a rule matches.
/// - Returns null if no rule matches.
/// - Handles condition-based, role-based, approval-based, and entitlement-based transitions.
class StepTransitionManager {
  const StepTransitionManager();

  /// Evaluate transition rules and return the target step ID.
  ///
  /// Returns null if no rule matches or if the step has no transition rules.
  String? evaluateTransition({
    required WorkflowStepConfig step,
    required FormValues values,
    List<String>? userRoles,
    Set<String>? userEntitlements,
  }) {
    if (step.transitionRules.isEmpty) {
      // No rules — allow transition.
      return null;
    }

    for (final rule in step.transitionRules) {
      final target = switch (rule) {
        ConditionBasedTransition r => _evaluateCondition(r, values),
        RoleBasedTransition r => _evaluateRole(r, userRoles),
        ApprovalBasedTransition r => _evaluateApproval(r, userRoles),
        EntitlementBasedTransition r => _evaluateEntitlement(r, userEntitlements),
      };

      if (target != null) return target;
    }

    return null;
  }

  String? _evaluateCondition(ConditionBasedTransition rule, FormValues values) {
    final fieldValue = values.get(rule.conditionFieldKey);
    if (fieldValue == rule.expectedValue) {
      return rule.targetStepId;
    }
    return null;
  }

  String? _evaluateRole(RoleBasedTransition rule, List<String>? userRoles) {
    if (userRoles == null) return null;
    for (final role in userRoles) {
      if (rule.requiredRoles.contains(role)) {
        return rule.targetStepId;
      }
    }
    return null;
  }

  String? _evaluateApproval(ApprovalBasedTransition rule, List<String>? userRoles) {
    if (userRoles == null) return null;
    for (final role in userRoles) {
      if (rule.approverRoles.contains(role)) {
        // In production, check approval state.
        return null;
      }
    }
    return null;
  }

  String? _evaluateEntitlement(
    EntitlementBasedTransition rule,
    Set<String>? userEntitlements,
  ) {
    if (userEntitlements == null) return null;
    final hasAll = rule.requiredEntitlements.every((ent) => userEntitlements.contains(ent));
    if (hasAll) {
      return rule.targetStepId;
    }
    return null;
  }
}
