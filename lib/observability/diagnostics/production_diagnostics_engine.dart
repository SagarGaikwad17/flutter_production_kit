import 'package:flutter_production_kit/observability/domain/entities/production_incident.dart';
import 'package:flutter_production_kit/observability/domain/entities/trace_span.dart';
import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/entities/security_event.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Production diagnostics engine — reconstructs full production flows for investigation.
///
/// Design rationale:
/// - Aggregates traces, audits, and security events for a single investigation view.
/// - Correlation IDs link all related data across modules.
/// - Timeline reconstruction shows the exact sequence of events.
/// - Root cause analysis helpers identify patterns.
///
/// Investigation flow:
///   1. Provide correlation ID or time range.
///   2. Engine gathers all related traces, audits, security events.
///   3. Events are sorted by timestamp for timeline view.
///   4. Root cause hints are generated based on patterns.
///   5. Investigation report is generated.
class ProductionDiagnosticsEngine {
  ProductionDiagnosticsEngine({
    required TraceRepository traceRepository,
    required AuditRepository auditRepository,
    required SecurityEventRepository securityEventRepository,
    required IncidentRepository incidentRepository,
  })  : _traceRepository = traceRepository,
        _auditRepository = auditRepository,
        _securityEventRepository = securityEventRepository,
        _incidentRepository = incidentRepository;

  final TraceRepository _traceRepository;
  final AuditRepository _auditRepository;
  final SecurityEventRepository _securityEventRepository;
  final IncidentRepository _incidentRepository;

  /// Investigate by correlation ID.
  Future<InvestigationReport> investigateByCorrelationId(String correlationId) async {
    final traces = await _traceRepository.getSpansByCorrelationId(correlationId);
    final audits = await _auditRepository.getEntriesByCorrelationId(correlationId);

    // Get security events by checking all actors in the traces/audits.
    final actorIds = {
      ...audits.map((a) => a.actorId),
    };

    final securityEvents = <SecurityEvent>[];
    for (final actorId in actorIds) {
      securityEvents.addAll(
        await _securityEventRepository.getEventsByActor(actorId),
      );
    }

    // Get related incidents.
    final incidents = await _incidentRepository.getOpenIncidents();
    final relatedIncidents = incidents.where((inc) {
      return inc.traceIds.contains(correlationId) ||
          inc.auditEntryIds.any((id) => audits.any((a) => a.id == id));
    }).toList();

    return _buildReport(
      correlationId: correlationId,
      traces: traces,
      audits: audits,
      securityEvents: securityEvents,
      incidents: relatedIncidents,
    );
  }

  /// Investigate by time range.
  Future<InvestigationReport> investigateByTimeRange({
    required DateTime start,
    required DateTime end,
    String? module,
  }) async {
    final traces = await _traceRepository.getSpansByTimeRange(start: start, end: end);
    final audits = await _auditRepository.getEntriesByTimeRange(start: start, end: end, module: module);

    return _buildReport(
      correlationId: 'time_range_${start.toIso8601String()}_${end.toIso8601String()}',
      traces: traces,
      audits: audits,
      securityEvents: const [],
      incidents: const [],
    );
  }

  /// Investigate a specific user's activity.
  Future<InvestigationReport> investigateUser({
    required String userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final audits = await _auditRepository.getEntriesByActor(userId);
    final securityEvents = await _securityEventRepository.getEventsByActor(userId);

    // Filter by time range if provided.
    final filteredAudits = start != null && end != null
        ? audits.where((a) => a.timestamp.isAfter(start) && a.timestamp.isBefore(end)).toList()
        : audits;

    final correlationIds = filteredAudits.map((a) => a.correlationId).whereType<String>().toSet();
    final traces = <TraceSpan>[];
    for (final corrId in correlationIds) {
      traces.addAll(await _traceRepository.getSpansByCorrelationId(corrId));
    }

    return _buildReport(
      correlationId: 'user_$userId',
      traces: traces,
      audits: filteredAudits,
      securityEvents: securityEvents,
      incidents: const [],
    );
  }

  // ── Report Building ────────────────────────────────────────────────────────

  InvestigationReport _buildReport({
    required String correlationId,
    required List<TraceSpan> traces,
    required List<AuditEntry> audits,
    required List<SecurityEvent> securityEvents,
    required List<ProductionIncident> incidents,
  }) {
    // Build timeline.
    final timeline = <TimelineEvent>[
      ...traces.map((t) => TimelineEvent(
            timestamp: t.startedAt,
            type: TimelineEventType.trace,
            description: '${t.module}.${t.operation} (${t.status.name})',
            moduleId: t.module,
            correlationId: t.correlationId,
          )),
      ...audits.map((a) => TimelineEvent(
            timestamp: a.timestamp,
            type: TimelineEventType.audit,
            description: '${a.module}.${a.action} → ${a.target} (${a.result.name})',
            moduleId: a.module,
            correlationId: a.correlationId,
          )),
      ...securityEvents.map((e) => TimelineEvent(
            timestamp: e.timestamp,
            type: TimelineEventType.security,
            description: '${e.eventType.name} (${e.severity.name}) — ${e.description}',
            moduleId: 'security',
            correlationId: e.correlationId,
          )),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Generate root cause hints.
    final rootCauseHints = _generateRootCauseHints(traces, audits, securityEvents);

    return InvestigationReport(
      correlationId: correlationId,
      generatedAt: DateTime.now(),
      traceCount: traces.length,
      auditCount: audits.length,
      securityEventCount: securityEvents.length,
      incidentCount: incidents.length,
      timeline: timeline,
      rootCauseHints: rootCauseHints,
      traces: traces,
      audits: audits,
      securityEvents: securityEvents,
      incidents: incidents,
    );
  }

  List<String> _generateRootCauseHints(
    List<TraceSpan> traces,
    List<AuditEntry> audits,
    List<SecurityEvent> securityEvents,
  ) {
    final hints = <String>[];

    // Check for error traces.
    final errorTraces = traces.where((t) => t.status == TraceStatus.error).toList();
    if (errorTraces.isNotEmpty) {
      hints.add('${errorTraces.length} trace(s) ended with error status.');
    }

    // Check for denied audits.
    final deniedAudits = audits.where((a) => a.result == AuditResult.denied).toList();
    if (deniedAudits.isNotEmpty) {
      hints.add('${deniedAudits.length} audit(s) recorded as denied.');
    }

    // Check for high-severity security events.
    final criticalSecurity = securityEvents
        .where((e) => e.severity == SecurityEventSeverity.critical)
        .toList();
    if (criticalSecurity.isNotEmpty) {
      hints.add('${criticalSecurity.length} critical security event(s) detected.');
    }

    // Check for failed payment patterns.
    final billingAudits = audits.where((a) => a.module == 'billing').toList();
    final failedBilling = billingAudits.where((a) => a.result == AuditResult.failure).toList();
    if (failedBilling.isNotEmpty) {
      hints.add('${failedBilling.length} billing failure(s) detected.');
    }

    return hints.isEmpty ? ['No obvious root cause detected.'] : hints;
  }
}

/// Investigation report — aggregated view of all related events.
class InvestigationReport {
  const InvestigationReport({
    required this.correlationId,
    required this.generatedAt,
    required this.traceCount,
    required this.auditCount,
    required this.securityEventCount,
    required this.incidentCount,
    required this.timeline,
    required this.rootCauseHints,
    required this.traces,
    required this.audits,
    required this.securityEvents,
    required this.incidents,
  });

  final String correlationId;
  final DateTime generatedAt;
  final int traceCount;
  final int auditCount;
  final int securityEventCount;
  final int incidentCount;
  final List<TimelineEvent> timeline;
  final List<String> rootCauseHints;
  final List<TraceSpan> traces;
  final List<AuditEntry> audits;
  final List<SecurityEvent> securityEvents;
  final List<ProductionIncident> incidents;
}

/// Timeline event — a single event in the investigation timeline.
class TimelineEvent {
  const TimelineEvent({
    required this.timestamp,
    required this.type,
    required this.description,
    required this.moduleId,
    this.correlationId,
  });

  final DateTime timestamp;
  final TimelineEventType type;
  final String description;
  final String moduleId;
  final String? correlationId;
}

enum TimelineEventType {
  trace,
  audit,
  security,
}
