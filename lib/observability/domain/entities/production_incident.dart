/// Production incident — tracks production issues for investigation.
///
/// Design rationale:
/// - Incidents aggregate related events into a single investigation unit.
/// - [traceIds] links to all related traces for full reconstruction.
/// - [auditEntryIds] links to audit entries for compliance evidence.
/// - [securityEventIds] links to security events for risk assessment.
/// - [severity] determines response SLA.
/// - [status] tracks investigation progress.
/// - NO sensitive data in incident descriptions.
/// - [rootCause] is populated after investigation completes.
class ProductionIncident {
  const ProductionIncident({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.module,
    this.description,
    this.affectedUsers = const [],
    this.traceIds = const [],
    this.auditEntryIds = const [],
    this.securityEventIds = const [],
    this.rootCause,
    this.resolution,
    this.resolvedAt,
    this.resolvedBy,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String? description;
  final IncidentSeverity severity;
  final IncidentStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String module;
  final List<String> affectedUsers;
  final List<String> traceIds;
  final List<String> auditEntryIds;
  final List<String> securityEventIds;
  final String? rootCause;
  final String? resolution;
  final String? resolvedBy;
  final Map<String, String> metadata;

  bool get isResolved => status == IncidentStatus.resolved;
  bool get isInvestigating => status == IncidentStatus.investigating;

  ProductionIncident resolve({
    required String rootCause,
    required String resolution,
    required String resolvedBy,
  }) {
    return ProductionIncident(
      id: id,
      title: title,
      description: description,
      severity: severity,
      status: IncidentStatus.resolved,
      createdAt: createdAt,
      module: module,
      affectedUsers: affectedUsers,
      traceIds: traceIds,
      auditEntryIds: auditEntryIds,
      securityEventIds: securityEventIds,
      rootCause: rootCause,
      resolution: resolution,
      resolvedAt: DateTime.now(),
      resolvedBy: resolvedBy,
      metadata: metadata,
    );
  }

  ProductionIncident addTrace(String traceId) {
    return ProductionIncident(
      id: id,
      title: title,
      description: description,
      severity: severity,
      status: status,
      createdAt: createdAt,
      module: module,
      affectedUsers: affectedUsers,
      traceIds: [...traceIds, traceId],
      auditEntryIds: auditEntryIds,
      securityEventIds: securityEventIds,
      rootCause: rootCause,
      resolution: resolution,
      resolvedAt: resolvedAt,
      resolvedBy: resolvedBy,
      metadata: metadata,
    );
  }

  ProductionIncident addAuditEntry(String auditEntryId) {
    return ProductionIncident(
      id: id,
      title: title,
      description: description,
      severity: severity,
      status: status,
      createdAt: createdAt,
      module: module,
      affectedUsers: affectedUsers,
      traceIds: traceIds,
      auditEntryIds: [...auditEntryIds, auditEntryId],
      securityEventIds: securityEventIds,
      rootCause: rootCause,
      resolution: resolution,
      resolvedAt: resolvedAt,
      resolvedBy: resolvedBy,
      metadata: metadata,
    );
  }
}

enum IncidentSeverity {
  low,
  medium,
  high,
  critical,
}

enum IncidentStatus {
  open,
  investigating,
  resolved,
  closed,
}
