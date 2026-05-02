/// Workflow step configuration — defines a single step in a multi-step form.
///
/// Design rationale:
/// - [id] is the stable identifier for this step.
/// - [order] determines the step sequence.
/// - [sectionIds] links to the form sections rendered in this step.
/// - [requiredRoles] restricts who can complete this step.
/// - [requiredEntitlements] enforces subscription-based access.
/// - [allowSkip] determines if the step can be skipped.
/// - [validationMode] controls when validation runs (onExit, onSubmit, lazy).
/// - [approvalRequired] determines if this step needs approval before proceeding.
/// - [transitionRules] define conditions for moving to the next step.
class WorkflowStepConfig {
  const WorkflowStepConfig({
    required this.id,
    required this.order,
    required this.title,
    required this.sectionIds,
    this.description,
    this.requiredRoles = const [],
    this.requiredEntitlements = const [],
    this.allowSkip = false,
    this.validationMode = StepValidationMode.onExit,
    this.approvalRequired = false,
    this.transitionRules = const [],
    this.metadata = const {},
  });

  final String id;
  final int order;
  final String title;
  final String? description;
  final List<String> sectionIds;
  final List<String> requiredRoles;
  final List<String> requiredEntitlements;
  final bool allowSkip;
  final StepValidationMode validationMode;
  final bool approvalRequired;
  final List<StepTransitionRule> transitionRules;
  final Map<String, String> metadata;

  bool get isConditional => transitionRules.isNotEmpty;
}

/// Step validation mode — when validation is triggered.
enum StepValidationMode {
  onExit,
  onSubmit,
  lazy,
  none,
}

/// Step transition rule — defines conditions for moving between steps.
sealed class StepTransitionRule {
  const StepTransitionRule();
}

final class ConditionBasedTransition extends StepTransitionRule {
  const ConditionBasedTransition({
    required this.conditionFieldKey,
    required this.expectedValue,
    this.targetStepId,
  });
  final String conditionFieldKey;
  final dynamic expectedValue;
  final String? targetStepId;
}

final class RoleBasedTransition extends StepTransitionRule {
  const RoleBasedTransition({
    required this.requiredRoles,
    this.targetStepId,
  });
  final List<String> requiredRoles;
  final String? targetStepId;
}

final class ApprovalBasedTransition extends StepTransitionRule {
  const ApprovalBasedTransition({
    required this.approverRoles,
    required this.approvalAction,
  });
  final List<String> approverRoles;
  final ApprovalAction approvalAction;
}

final class EntitlementBasedTransition extends StepTransitionRule {
  const EntitlementBasedTransition({
    required this.requiredEntitlements,
    this.targetStepId,
  });
  final List<String> requiredEntitlements;
  final String? targetStepId;
}

enum ApprovalAction { approve, reject, requestRevision }
