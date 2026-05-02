/// Diagnostic report — detailed diagnostic information for debugging.
///
/// Design rationale:
/// - Each diagnostic has a category, severity, and actionable resolution.
/// - Diagnostics are grouped by module for focused debugging.
/// - Resolutions include code examples where applicable.
/// - Diagnostics are timestamped for temporal analysis.
///
/// Diagnostic categories:
/// - setup — project configuration issues.
/// - flavor — flavor/environment mismatch issues.
/// - auth — authentication/session issues.
/// - network — API connectivity issues.
/// - permissions — role/access issues.
/// - sync — offline sync conflicts.
/// - billing — subscription/entitlement issues.
/// - tenant — multi-tenant isolation issues.
/// - release — deployment/rollout issues.
class DiagnosticReport {
  const DiagnosticReport({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.resolution,
    this.module,
    this.timestamp,
    this.codeExample,
    this.relatedDiagnostics = const [],
    this.isResolved = false,
  });

  final String id;
  final String category;
  final DiagnosticSeverity severity;
  final String title;
  final String description;
  final String resolution;
  final String? module;
  final DateTime? timestamp;
  final String? codeExample;
  final List<String> relatedDiagnostics;
  final bool isResolved;

  bool get isCritical => severity == DiagnosticSeverity.critical;
  bool get isWarning => severity == DiagnosticSeverity.warning;
  bool get isInfo => severity == DiagnosticSeverity.info;
}

enum DiagnosticSeverity {
  critical,
  warning,
  info,
}

/// Failure explanation — human-readable explanation of a failure.
class FailureExplanation {
  const FailureExplanation({
    required this.failureType,
    required this.summary,
    required this.rootCause,
    required this.resolution,
    this.codeExample,
    this.relatedDocs,
    this.estimatedFixTime,
  });

  final String failureType;
  final String summary;
  final String rootCause;
  final String resolution;
  final String? codeExample;
  final List<String>? relatedDocs;
  final String? estimatedFixTime;
}

/// Diagnostic collection — grouped diagnostics for a session.
class DiagnosticCollection {
  const DiagnosticCollection({
    required this.sessionId,
    required this.diagnostics,
    this.timestamp,
  });

  final String sessionId;
  final List<DiagnosticReport> diagnostics;
  final DateTime? timestamp;

  List<DiagnosticReport> get criticalDiagnostics =>
      diagnostics.where((d) => d.isCritical).toList();

  List<DiagnosticReport> get warningDiagnostics =>
      diagnostics.where((d) => d.isWarning).toList();

  bool get hasCriticalIssues => criticalDiagnostics.isNotEmpty;
  bool get hasWarnings => warningDiagnostics.isNotEmpty;

  int get totalIssues => diagnostics.length;
  int get resolvedCount => diagnostics.where((d) => d.isResolved).length;
}
