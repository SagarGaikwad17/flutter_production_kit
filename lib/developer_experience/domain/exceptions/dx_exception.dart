/// Developer experience exception hierarchy.
///
/// Design rationale:
/// - Each exception maps to a specific developer experience failure mode.
/// - Exceptions include actionable guidance for resolution.
/// - No sensitive data in exception messages.
sealed class DXException implements Exception {
  const DXException({required this.message, this.guidance});
  final String message;
  final String? guidance;

  @override
  String toString() =>
      'DXException: $message${guidance != null ? ' (guidance: $guidance)' : ''}';
}

/// Project setup failed — project could not be initialized.
final class ProjectSetupFailedException extends DXException {
  const ProjectSetupFailedException({
    required super.message,
    super.guidance = 'Run flutter_runtime doctor to diagnose system issues',
  });
}

/// Module addition failed — module could not be added to project.
final class ModuleAdditionFailedException extends DXException {
  const ModuleAdditionFailedException({
    required super.message,
    required this.moduleName,
    super.guidance = 'Ensure the module is compatible with your project configuration',
  });
  final String moduleName;
}

/// Template generation failed — starter template could not be generated.
final class TemplateGenerationFailedException extends DXException {
  const TemplateGenerationFailedException({
    required super.message,
    required this.templateName,
    super.guidance = 'Check that the template name is valid and supported',
  });
  final String templateName;
}

/// CLI command failed — CLI command could not be executed.
final class CLICommandFailedException extends DXException {
  const CLICommandFailedException({
    required super.message,
    required this.command,
    this.exitCode,
    super.guidance = 'Check the command syntax and try again',
  });
  final String command;
  final int? exitCode;
}

/// Migration failed — migration could not be completed.
final class MigrationFailedException extends DXException {
  const MigrationFailedException({
    required super.message,
    required this.fromVersion,
    required this.toVersion,
    this.failedSteps = const [],
    super.guidance = 'Follow the migration guide step by step',
  });
  final String fromVersion;
  final String toVersion;
  final List<String> failedSteps;
}

/// Architecture violation detected — project architecture is invalid.
final class ArchitectureViolationException extends DXException {
  const ArchitectureViolationException({
    required super.message,
    required this.violations,
    super.guidance = 'Review the architecture guardrails and fix violations',
  });
  final List<String> violations;
}

/// Diagnostic check failed — diagnostic found critical issues.
final class DiagnosticCheckFailedException extends DXException {
  const DiagnosticCheckFailedException({
    required super.message,
    required this.diagnostics,
    super.guidance = 'Resolve critical diagnostics before proceeding',
  });
  final List<String> diagnostics;
}

/// Onboarding incomplete — developer onboarding is not complete.
final class OnboardingIncompleteException extends DXException {
  const OnboardingIncompleteException({
    required super.message,
    required this.missingSteps,
    super.guidance = 'Complete all onboarding steps before using the framework',
  });
  final List<String> missingSteps;
}

/// Workflow error — developer workflow encountered an error.
final class WorkflowErrorException extends DXException {
  const WorkflowErrorException({
    required super.message,
    required this.workflowName,
    required this.step,
    super.guidance = 'Check the workflow configuration and retry',
  });
  final String workflowName;
  final String step;
}
