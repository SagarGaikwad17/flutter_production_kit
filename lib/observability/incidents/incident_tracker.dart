import 'package:flutter_production_kit/observability/domain/entities/production_incident.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Incident tracker — manages production incidents for investigation.
///
/// Design rationale:
/// - Incidents aggregate related events (traces, audits, security events).
/// - Each incident has a severity level and investigation status.
/// - Incidents are linked to correlation IDs for full trace reconstruction.
/// - Root cause and resolution are recorded after investigation.
/// - Integration with audit trail for compliance evidence.
///
/// Incident flow:
///   1. Detect issue (error spike, security event, user report).
///   2. Create incident with severity and description.
///   3. Link related traces, audit entries, security events.
///   4. Investigate — add evidence as discovered.
///   5. Record root cause and resolution.
///   6. Close incident.
class IncidentTracker {
  IncidentTracker({
    required IncidentRepository incidentRepository,
  }) : _incidentRepository = incidentRepository;

  final IncidentRepository _incidentRepository;

  /// Create a new incident.
  Future<String> create({
    required String title,
    required IncidentSeverity severity,
    required String module,
    String? description,
    List<String>? affectedUsers,
    String? correlationId,
  }) async {
    final incident = ProductionIncident(
      id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      severity: severity,
      status: IncidentStatus.open,
      createdAt: DateTime.now(),
      module: module,
      description: description,
      affectedUsers: affectedUsers ?? [],
      traceIds: correlationId != null ? [correlationId] : [],
    );

    await _incidentRepository.saveIncident(incident);
    return incident.id;
  }

  /// Start investigating an incident.
  Future<void> startInvestigation(String incidentId) async {
    final incident = await _incidentRepository.getIncident(incidentId);
    if (incident == null) return;

    final updated = ProductionIncident(
      id: incident.id,
      title: incident.title,
      description: incident.description,
      severity: incident.severity,
      status: IncidentStatus.investigating,
      createdAt: incident.createdAt,
      module: incident.module,
      affectedUsers: incident.affectedUsers,
      traceIds: incident.traceIds,
      auditEntryIds: incident.auditEntryIds,
      securityEventIds: incident.securityEventIds,
      rootCause: incident.rootCause,
      resolution: incident.resolution,
      resolvedAt: incident.resolvedAt,
      resolvedBy: incident.resolvedBy,
      metadata: incident.metadata,
    );

    await _incidentRepository.updateIncident(updated);
  }

  /// Add a trace to an incident.
  Future<void> addTrace(String incidentId, String traceId) async {
    final incident = await _incidentRepository.getIncident(incidentId);
    if (incident == null) return;

    await _incidentRepository.updateIncident(incident.addTrace(traceId));
  }

  /// Add an audit entry to an incident.
  Future<void> addAuditEntry(String incidentId, String auditEntryId) async {
    final incident = await _incidentRepository.getIncident(incidentId);
    if (incident == null) return;

    await _incidentRepository.updateIncident(incident.addAuditEntry(auditEntryId));
  }

  /// Resolve an incident.
  Future<void> resolve({
    required String incidentId,
    required String rootCause,
    required String resolution,
    required String resolvedBy,
  }) async {
    final incident = await _incidentRepository.getIncident(incidentId);
    if (incident == null) return;

    await _incidentRepository.updateIncident(
      incident.resolve(
        rootCause: rootCause,
        resolution: resolution,
        resolvedBy: resolvedBy,
      ),
    );
  }

  /// Get open incidents.
  Future<List<ProductionIncident>> getOpenIncidents() {
    return _incidentRepository.getOpenIncidents();
  }

  /// Get incidents by severity.
  Future<List<ProductionIncident>> getBySeverity(IncidentSeverity severity) {
    return _incidentRepository.getIncidentsBySeverity(severity);
  }

  /// Get incidents by module.
  Future<List<ProductionIncident>> getByModule(String module) {
    return _incidentRepository.getIncidentsByModule(module);
  }

  /// Get an incident by ID.
  Future<ProductionIncident?> getById(String incidentId) {
    return _incidentRepository.getIncident(incidentId);
  }
}
