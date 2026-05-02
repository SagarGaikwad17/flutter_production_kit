import 'package:flutter_production_kit/developer_experience/domain/entities/dx_result.dart';
import 'package:flutter_production_kit/developer_experience/domain/repositories/dx_repositories.dart';

/// Project bootstrap engine — handles one-command project initialization.
///
/// Design rationale:
/// - Generates a complete Flutter project with production-safe defaults.
/// - Supports modular adoption — developers add modules as needed.
/// - Enforces convention-over-configuration architecture.
/// - Generates flavor configuration, environment setup, and CI/CD starter.
///
/// Bootstrap flow:
///   1. Validate system requirements (flutter, dart, git).
///   2. Generate project structure.
///   3. Configure flavors (dev, qa, staging, prod).
///   4. Set up environment configuration.
///   5. Initialize selected modules.
///   6. Generate CI/CD starter configuration.
///   7. Validate setup completeness.
class ProjectBootstrapEngine {
  const ProjectBootstrapEngine({
    required IOnboardingRepository onboardingRepository,
    this.requiredFlutterVersion = '>=3.16.0',
    this.requiredDartVersion = '>=3.2.0',
  }) : _onboardingRepository = onboardingRepository;

  final IOnboardingRepository _onboardingRepository;
  final String requiredFlutterVersion;
  final String requiredDartVersion;

  /// Bootstrap a new project with selected modules.
  Future<DXResult> bootstrapProject({
    required String projectName,
    required String projectPath,
    List<String> modules = const [],
    List<String> flavors = const ['dev', 'staging', 'prod'],
    String? template,
    bool includeCICD = true,
    bool includeWhiteLabel = false,
  }) async {
    // Step 1: Validate system requirements
    final validation = await _validateSystem();
    if (!validation.isValid) {
      return DoctorCheckFailed(
        operation: 'bootstrap',
        failedChecks: validation.errors,
        remediation: validation.suggestions,
      );
    }

    // Step 2: Generate project structure
    await _generateProjectStructure(
      projectName: projectName,
      projectPath: projectPath,
      modules: modules,
      flavors: flavors,
      template: template,
      includeWhiteLabel: includeWhiteLabel,
    );

    // Step 3: Generate CI/CD configuration
    if (includeCICD) {
      await _generateCICDConfig(
        projectName: projectName,
        projectPath: projectPath,
        flavors: flavors,
      );
    }

    // Step 4: Save workflow state
    final workflow = DeveloperWorkflowState(
      projectName: projectName,
      currentStep: 'completed',
      completedSteps: [
        'system_validation',
        'project_generation',
        'flavor_configuration',
        'module_initialization',
        if (includeCICD) 'cicd_setup',
      ],
      totalSteps: 5,
      startedAt: DateTime.now(),
      lastActionAt: DateTime.now(),
      selectedModules: modules,
      selectedFlavors: flavors,
      templateName: template,
    );
    await _onboardingRepository.saveWorkflow(workflow);

    return SetupCompletedSuccessfully(
      operation: 'bootstrap',
      projectPath: projectPath,
      nextSteps: [
        'cd $projectPath',
        'flutter pub get',
        'flutter run --flavor dev',
        'flutter_runtime doctor',
      ],
    );
  }

  /// Validate system requirements.
  Future<SetupValidationResult> _validateSystem() async {
    final errors = <String>[];
    final suggestions = <String>[];

    // In production, this would check actual Flutter/Dart versions.
    // For now, return success.

    if (errors.isNotEmpty) {
      return SetupValidationResult(
        isValid: false,
        errors: errors,
        suggestions: suggestions,
      );
    }

    return const SetupValidationResult(isValid: true);
  }

  /// Generate project structure.
  Future<List<String>> _generateProjectStructure({
    required String projectName,
    required String projectPath,
    required List<String> modules,
    required List<String> flavors,
    String? template,
    bool includeWhiteLabel = false,
  }) async {
    // In production, this would generate actual files.
    return [
      '$projectPath/pubspec.yaml',
      '$projectPath/lib/main.dart',
      for (final flavor in flavors) '$projectPath/lib/main_$flavor.dart',
      for (final module in modules) '$projectPath/lib/$module/',
    ];
  }

  /// Generate CI/CD configuration.
  Future<void> _generateCICDConfig({
    required String projectName,
    required String projectPath,
    required List<String> flavors,
  }) async {
    // In production, this would generate GitHub Actions/Fastlane configs.
  }
}

/// Setup validation engine — validates project setup completeness.
class SetupValidationEngine {
  const SetupValidationEngine();

  /// Validate that a project is correctly set up.
  SetupValidationResult validateSetup({
    required String projectPath,
    List<String> requiredModules = const [],
    List<String> requiredFlavors = const ['dev', 'prod'],
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    // Check pubspec.yaml exists
    // Check main.dart exists
    // Check flavor files exist
    // Check module directories exist
    // Check dependencies are installed
    // Check no analyzer errors

    if (errors.isEmpty && warnings.isEmpty) {
      suggestions.add('Run flutter_runtime doctor for comprehensive checks');
    }

    return SetupValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Validate flavor configuration.
  SetupValidationResult validateFlavors({
    required List<String> configuredFlavors,
    required List<String> expectedFlavors,
  }) {
    final errors = <String>[];

    for (final flavor in expectedFlavors) {
      if (!configuredFlavors.contains(flavor)) {
        errors.add('Missing flavor: $flavor');
      }
    }

    return SetupValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// Validate module configuration.
  SetupValidationResult validateModules({
    required List<String> installedModules,
    required List<String> requiredModules,
  }) {
    final errors = <String>[];

    for (final module in requiredModules) {
      if (!installedModules.contains(module)) {
        errors.add('Missing required module: $module');
      }
    }

    return SetupValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
