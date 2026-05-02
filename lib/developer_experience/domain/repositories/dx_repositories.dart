import 'package:flutter_production_kit/developer_experience/domain/entities/diagnostic_report.dart';
import 'package:flutter_production_kit/developer_experience/domain/entities/dx_result.dart';

/// Repository interface for diagnostic data access.
abstract class IDiagnosticRepository {
  Future<List<DiagnosticReport>> getDiagnosticsByCategory(String category);
  Future<List<DiagnosticReport>> getDiagnosticsByModule(String module);
  Future<void> saveDiagnostic(DiagnosticReport diagnostic);
  Future<void> markResolved(String diagnosticId);
  Future<DiagnosticCollection> getSessionDiagnostics(String sessionId);
}

/// Repository interface for onboarding data access.
abstract class IOnboardingRepository {
  Future<DeveloperWorkflowState?> getWorkflow(String projectName);
  Future<void> saveWorkflow(DeveloperWorkflowState workflow);
  Future<List<String>> getCompletedOnboardingSteps(String projectName);
}

/// Repository interface for template data access.
abstract class ITemplateRepository {
  Future<Map<String, dynamic>?> getTemplateConfig(String templateName);
  Future<List<String>> getAvailableTemplates();
  Future<void> saveTemplateConfig(String templateName, Map<String, dynamic> config);
}

/// Repository interface for migration data access.
abstract class DXMigrationRepository {
  Future<Map<String, dynamic>?> getMigrationGuide(String fromVersion, String toVersion);
  Future<void> recordMigrationAttempt({
    required String fromVersion,
    required String toVersion,
    required bool success,
    String? failureReason,
  });
}
