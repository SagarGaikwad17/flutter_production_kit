import 'package:flutter_production_kit/developer_experience/domain/entities/diagnostic_report.dart';
import 'package:flutter_production_kit/developer_experience/domain/repositories/dx_repositories.dart';

/// Developer diagnostics engine — provides clear debugging guidance.
///
/// Design rationale:
/// - Every failure has a human-readable explanation.
/// - Diagnostics are grouped by module for focused debugging.
/// - Resolutions include code examples where applicable.
/// - Related diagnostics are linked for comprehensive debugging.
///
/// Diagnostic categories:
/// - setup — project configuration issues.
/// - flavor — flavor/environment mismatch.
/// - auth — authentication/session issues.
/// - network — API connectivity issues.
/// - permissions — role/access issues.
/// - sync — offline sync conflicts.
/// - billing — subscription/entitlement issues.
/// - tenant — multi-tenant isolation issues.
/// - release — deployment/rollout issues.
class DeveloperDiagnosticsEngine {
  const DeveloperDiagnosticsEngine({
    required IDiagnosticRepository diagnosticRepository,
  }) : _diagnosticRepository = diagnosticRepository;

  final IDiagnosticRepository _diagnosticRepository;

  /// Run diagnostics for a specific category.
  Future<DiagnosticCollection> runDiagnostics({
    required String sessionId,
    required String category,
  }) async {
    final diagnostics = await _diagnosticRepository.getDiagnosticsByCategory(
      category,
    );

    return DiagnosticCollection(
      sessionId: sessionId,
      diagnostics: diagnostics,
      timestamp: DateTime.now(),
    );
  }

  /// Run all diagnostics.
  Future<DiagnosticCollection> runAllDiagnostics({
    required String sessionId,
  }) async {
    final categories = [
      'setup',
      'flavor',
      'auth',
      'network',
      'permissions',
      'sync',
      'billing',
      'tenant',
      'release',
    ];

    final allDiagnostics = <DiagnosticReport>[];
    for (final category in categories) {
      final diagnostics = await _diagnosticRepository.getDiagnosticsByCategory(
        category,
      );
      allDiagnostics.addAll(diagnostics);
    }

    return DiagnosticCollection(
      sessionId: sessionId,
      diagnostics: allDiagnostics,
      timestamp: DateTime.now(),
    );
  }

  /// Get diagnostic for a specific failure.
  DiagnosticReport? getDiagnosticForFailure(String failureType) {
    return _diagnosticMap[failureType];
  }

  /// Get failure explanation for a specific error.
  FailureExplanation? explainFailure(String errorType) {
    return _failureExplanations[errorType];
  }

  static const Map<String, DiagnosticReport> _diagnosticMap = {
    'flavor_mismatch': DiagnosticReport(
      id: 'flavor_001',
      category: 'flavor',
      severity: DiagnosticSeverity.critical,
      title: 'Flavor mismatch detected',
      description: 'The app is running with the wrong flavor configuration.',
      resolution: 'Run: flutter run --flavor <correct_flavor>',
    ),
    'token_refresh_failure': DiagnosticReport(
      id: 'auth_001',
      category: 'auth',
      severity: DiagnosticSeverity.warning,
      title: 'Token refresh failure',
      description: 'The auth token could not be refreshed automatically.',
      resolution: 'Check refresh token validity and network connectivity.',
    ),
    'sync_conflict': DiagnosticReport(
      id: 'sync_001',
      category: 'sync',
      severity: DiagnosticSeverity.warning,
      title: 'Offline sync conflict detected',
      description: 'Local and server data have conflicting changes.',
      resolution: 'Review conflict resolution strategy in offline config.',
    ),
  };

  static const Map<String, FailureExplanation> _failureExplanations = {
    'auth_unauthorized': FailureExplanation(
      failureType: 'auth_unauthorized',
      summary: 'Request was rejected due to missing or invalid authentication.',
      rootCause: 'The auth token is expired, missing, or malformed.',
      resolution: 'Check that the user is logged in and the token is valid. '
          'Verify the token refresh mechanism is working.',
      codeExample: '''
// Check auth state
final authState = await authEngine.getCurrentState();
if (!authState.isAuthenticated) {
  // Redirect to login
}
''',
      estimatedFixTime: '5-10 minutes',
    ),
    'network_timeout': FailureExplanation(
      failureType: 'network_timeout',
      summary: 'API request timed out.',
      rootCause: 'Network connectivity issue or server is unresponsive.',
      resolution: 'Check internet connectivity. Verify the API endpoint is '
          'reachable. Consider increasing timeout duration.',
      estimatedFixTime: '2-5 minutes',
    ),
    'billing_entitlement_denied': FailureExplanation(
      failureType: 'billing_entitlement_denied',
      summary: 'Feature access denied due to subscription status.',
      rootCause: 'The user\'s subscription does not include this feature.',
      resolution: 'Check the user\'s subscription tier and entitlements. '
          'Upgrade subscription or enable feature override.',
      estimatedFixTime: '5-15 minutes',
    ),
  };
}

/// Failure explainer — provides human-readable failure explanations.
class FailureExplainer {
  const FailureExplainer();

  /// Explain a failure with context.
  FailureExplanation explain({
    required String failureType,
    Map<String, String>? context,
  }) {
    return _defaultExplanations[failureType] ??
        const FailureExplanation(
          failureType: 'unknown',
          summary: 'An unexpected error occurred.',
          rootCause: 'The root cause could not be determined automatically.',
          resolution: 'Check the error logs and try again.',
        );
  }

  /// Get guided debugging path for a failure.
  List<String> getDebuggingPath(String failureType) {
    return _debuggingPaths[failureType] ?? [
      'Check the error message and stack trace',
      'Search the documentation for similar issues',
      'Review related diagnostic reports',
      'If unresolved, file an issue with error details',
    ];
  }

  static const Map<String, FailureExplanation> _defaultExplanations = {
    'setup_incomplete': FailureExplanation(
      failureType: 'setup_incomplete',
      summary: 'Project setup is incomplete.',
      rootCause: 'Required configuration files or dependencies are missing.',
      resolution: 'Run flutter_runtime doctor to identify missing components.',
    ),
    'module_not_registered': FailureExplanation(
      failureType: 'module_not_registered',
      summary: 'Module is not registered in the DI container.',
      rootCause: 'The module engine was not registered during app initialization.',
      resolution: 'Register the module in your DI container during bootstrap.',
    ),
    'flavor_config_missing': FailureExplanation(
      failureType: 'flavor_config_missing',
      summary: 'Flavor configuration is missing.',
      rootCause: 'The flavor-specific configuration file does not exist.',
      resolution: 'Create the flavor configuration file or use an existing flavor.',
    ),
  };

  static const Map<String, List<String>> _debuggingPaths = {
    'auth_failure': [
      '1. Check if the user is logged in',
      '2. Verify the auth token is not expired',
      '3. Check network connectivity',
      '4. Review auth engine logs',
      '5. Try refreshing the token manually',
    ],
    'sync_failure': [
      '1. Check network connectivity',
      '2. Verify offline queue is not corrupted',
      '3. Check for sync conflicts',
      '4. Review sync engine logs',
      '5. Try clearing and re-syncing',
    ],
    'billing_failure': [
      '1. Check subscription status',
      '2. Verify entitlement mapping',
      '3. Check payment processing logs',
      '4. Review billing engine state',
      '5. Try refreshing subscription data',
    ],
  };
}
