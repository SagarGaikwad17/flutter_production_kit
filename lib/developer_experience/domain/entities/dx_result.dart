/// Developer experience result — explicit outcome of any DX operation.
///
/// Design rationale:
/// - Sealed hierarchy — all outcomes are known and exhaustive.
/// - No bool-only checks — each result carries context and guidance.
/// - CLI can render rich output based on result type.
/// - Onboarding flow can branch based on result.
///
/// Outcomes:
/// - ProjectSetupValidated: project is correctly configured and ready.
/// - ArchitectureIssueDetected: project architecture has issues to fix.
/// - MigrationGuideRequired: version upgrade requires migration steps.
/// - ConfigurationMismatchBlocked: configuration is incorrect for environment.
/// - ContributorOnboardingApproved: contributor is ready to start.
/// - DiagnosticsResolutionSuggested: diagnostic found issue with fix.
/// - SetupCompletedSuccessfully: project setup finished.
/// - ModuleAddedSuccessfully: module added to existing project.
/// - DoctorCheckPassed: all system checks passed.
/// - DoctorCheckFailed: system check failed with remediation steps.
sealed class DXResult {
  const DXResult({required this.operation});
  final String operation;

  bool get isSuccess =>
      this is ProjectSetupValidated ||
      this is SetupCompletedSuccessfully ||
      this is ModuleAddedSuccessfully ||
      this is DoctorCheckPassed ||
      this is ContributorOnboardingApproved ||
      this is DiagnosticsResolutionSuggested;
}

/// Project setup validated — project is correctly configured.
final class ProjectSetupValidated extends DXResult {
  const ProjectSetupValidated({
    required super.operation,
    required this.projectName,
    this.flavors = const [],
    this.modules = const [],
    this.warnings = const [],
  });
  final String projectName;
  final List<String> flavors;
  final List<String> modules;
  final List<String> warnings;
}

/// Architecture issue detected — project has architectural problems.
final class ArchitectureIssueDetected extends DXResult {
  const ArchitectureIssueDetected({
    required super.operation,
    required this.issues,
    this.severity = 'warning',
    this.remediation = const [],
  });
  final List<String> issues;
  final String severity;
  final List<String> remediation;
}

/// Migration guide required — upgrade needs migration steps.
final class MigrationGuideRequired extends DXResult {
  const MigrationGuideRequired({
    required super.operation,
    required this.fromVersion,
    required this.toVersion,
    required this.breakingChanges,
    this.guideUrl,
    this.estimatedTimeMinutes,
  });
  final String fromVersion;
  final String toVersion;
  final List<String> breakingChanges;
  final String? guideUrl;
  final int? estimatedTimeMinutes;
}

/// Configuration mismatch blocked — configuration is wrong.
final class ConfigurationMismatchBlocked extends DXResult {
  const ConfigurationMismatchBlocked({
    required super.operation,
    required this.expected,
    required this.actual,
    this.remediation,
  });
  final String expected;
  final String actual;
  final String? remediation;
}

/// Contributor onboarding approved — contributor is ready.
final class ContributorOnboardingApproved extends DXResult {
  const ContributorOnboardingApproved({
    required super.operation,
    required this.contributorId,
    this.requiredReadings = const [],
    this.firstIssue,
  });
  final String contributorId;
  final List<String> requiredReadings;
  final String? firstIssue;
}

/// Diagnostics resolution suggested — issue found with fix.
final class DiagnosticsResolutionSuggested extends DXResult {
  const DiagnosticsResolutionSuggested({
    required super.operation,
    required this.issue,
    required this.explanation,
    required this.resolution,
    this.severity = 'info',
  });
  final String issue;
  final String explanation;
  final String resolution;
  final String severity;
}

/// Setup completed successfully — project setup finished.
final class SetupCompletedSuccessfully extends DXResult {
  const SetupCompletedSuccessfully({
    required super.operation,
    required this.projectPath,
    this.nextSteps = const [],
  });
  final String projectPath;
  final List<String> nextSteps;
}

/// Module added successfully — module added to existing project.
final class ModuleAddedSuccessfully extends DXResult {
  const ModuleAddedSuccessfully({
    required super.operation,
    required this.moduleName,
    this.filesCreated = const [],
    this.nextSteps = const [],
  });
  final String moduleName;
  final List<String> filesCreated;
  final List<String> nextSteps;
}

/// Doctor check passed — all system checks passed.
final class DoctorCheckPassed extends DXResult {
  const DoctorCheckPassed({
    required super.operation,
    this.checks = const [],
  });
  final List<String> checks;
}

/// Doctor check failed — system check failed.
final class DoctorCheckFailed extends DXResult {
  const DoctorCheckFailed({
    required super.operation,
    required this.failedChecks,
    this.remediation = const [],
  });
  final List<String> failedChecks;
  final List<String> remediation;
}

/// Developer workflow state — tracks developer progress through onboarding.
class DeveloperWorkflowState {
  const DeveloperWorkflowState({
    required this.projectName,
    required this.currentStep,
    required this.completedSteps,
    required this.totalSteps,
    this.startedAt,
    this.lastActionAt,
    this.selectedModules = const [],
    this.selectedFlavors = const [],
    this.templateName,
  });

  final String projectName;
  final String currentStep;
  final List<String> completedSteps;
  final int totalSteps;
  final DateTime? startedAt;
  final DateTime? lastActionAt;
  final List<String> selectedModules;
  final List<String> selectedFlavors;
  final String? templateName;

  double get progress => totalSteps > 0 ? completedSteps.length / totalSteps : 0;
  bool get isComplete => completedSteps.length >= totalSteps;

  DeveloperWorkflowState advanceTo(String nextStep) {
    return copyWith(
      currentStep: nextStep,
      completedSteps: [...completedSteps, currentStep],
      lastActionAt: DateTime.now(),
    );
  }

  DeveloperWorkflowState addModule(String module) {
    return copyWith(
      selectedModules: [...selectedModules, module],
      lastActionAt: DateTime.now(),
    );
  }

  DeveloperWorkflowState copyWith({
    String? currentStep,
    List<String>? completedSteps,
    DateTime? lastActionAt,
    List<String>? selectedModules,
    List<String>? selectedFlavors,
  }) {
    return DeveloperWorkflowState(
      projectName: projectName,
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      totalSteps: totalSteps,
      startedAt: startedAt,
      lastActionAt: lastActionAt ?? this.lastActionAt,
      selectedModules: selectedModules ?? this.selectedModules,
      selectedFlavors: selectedFlavors ?? this.selectedFlavors,
      templateName: templateName,
    );
  }
}

/// Setup validation result — outcome of setup validation.
class SetupValidationResult {
  const SetupValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> suggestions;
}
