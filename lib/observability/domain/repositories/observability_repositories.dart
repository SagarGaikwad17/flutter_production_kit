import 'package:flutter_production_kit/observability/domain/entities/audit_entry.dart';
import 'package:flutter_production_kit/observability/domain/entities/log_entry.dart';
import 'package:flutter_production_kit/observability/domain/entities/production_incident.dart';
import 'package:flutter_production_kit/observability/domain/entities/security_event.dart';
import 'package:flutter_production_kit/observability/domain/entities/trace_span.dart';

/// Abstract repository for audit entries.
abstract class AuditRepository {
  const AuditRepository();

  /// Save an audit entry (append-only).
  Future<void> saveAuditEntry(AuditEntry entry);

  /// Get an audit entry by ID.
  Future<AuditEntry?> getAuditEntry(String entryId);

  /// Get audit entries for a specific actor.
  Future<List<AuditEntry>> getEntriesByActor(String actorId);

  /// Get audit entries for a specific action.
  Future<List<AuditEntry>> getEntriesByAction(String action);

  /// Get audit entries within a time range.
  Future<List<AuditEntry>> getEntriesByTimeRange({
    required DateTime start,
    required DateTime end,
    String? module,
  });

  /// Get audit entries by correlation ID.
  Future<List<AuditEntry>> getEntriesByCorrelationId(String correlationId);

  /// Get audit entries by retention category.
  Future<List<AuditEntry>> getEntriesByRetentionCategory(
    AuditRetentionCategory category,
  );

  /// Delete entries past retention period.
  Future<int> deleteExpiredEntries();
}

/// Abstract repository for trace spans.
abstract class TraceRepository {
  const TraceRepository();

  /// Save a trace span.
  Future<void> saveSpan(TraceSpan span);

  /// Get a span by ID.
  Future<TraceSpan?> getSpan(String traceId, String spanId);

  /// Get all spans for a trace.
  Future<List<TraceSpan>> getSpansByTraceId(String traceId);

  /// Get traces by correlation ID.
  Future<List<TraceSpan>> getSpansByCorrelationId(String correlationId);

  /// Get traces by module.
  Future<List<TraceSpan>> getSpansByModule(String module);

  /// Get traces within a time range.
  Future<List<TraceSpan>> getSpansByTimeRange({
    required DateTime start,
    required DateTime end,
  });

  /// Delete expired traces.
  Future<int> deleteExpiredTraces();
}

/// Abstract repository for security events.
abstract class SecurityEventRepository {
  const SecurityEventRepository();

  /// Save a security event.
  Future<void> saveSecurityEvent(SecurityEvent event);

  /// Get a security event by ID.
  Future<SecurityEvent?> getSecurityEvent(String eventId);

  /// Get security events by actor.
  Future<List<SecurityEvent>> getEventsByActor(String actorId);

  /// Get security events by type.
  Future<List<SecurityEvent>> getEventsByType(SecurityEventType type);

  /// Get security events by severity.
  Future<List<SecurityEvent>> getEventsBySeverity(
    SecurityEventSeverity severity,
  );

  /// Get unacknowledged security events.
  Future<List<SecurityEvent>> getUnacknowledgedEvents();

  /// Get high-risk events.
  Future<List<SecurityEvent>> getHighRiskEvents();

  /// Update event response status.
  Future<void> updateEventResponseStatus(
    String eventId,
    SecurityEventResponseStatus status,
  );
}

/// Abstract repository for log entries.
abstract class LogRepository {
  const LogRepository();

  /// Save a log entry.
  Future<void> saveLogEntry(LogEntry entry);

  /// Get log entries by level.
  Future<List<LogEntry>> getEntriesByLevel(LogLevel level);

  /// Get log entries by module.
  Future<List<LogEntry>> getEntriesByModule(String module);

  /// Get log entries by correlation ID.
  Future<List<LogEntry>> getEntriesByCorrelationId(String correlationId);

  /// Get log entries within a time range.
  Future<List<LogEntry>> getEntriesByTimeRange({
    required DateTime start,
    required DateTime end,
  });

  /// Get critical entries (error/fatal).
  Future<List<LogEntry>> getCriticalEntries();

  /// Delete expired log entries.
  Future<int> deleteExpiredEntries();
}

/// Abstract repository for production incidents.
abstract class IncidentRepository {
  const IncidentRepository();

  /// Save an incident.
  Future<void> saveIncident(ProductionIncident incident);

  /// Get an incident by ID.
  Future<ProductionIncident?> getIncident(String incidentId);

  /// Get open incidents.
  Future<List<ProductionIncident>> getOpenIncidents();

  /// Get incidents by severity.
  Future<List<ProductionIncident>> getIncidentsBySeverity(
    IncidentSeverity severity,
  );

  /// Get incidents by module.
  Future<List<ProductionIncident>> getIncidentsByModule(String module);

  /// Update an incident.
  Future<void> updateIncident(ProductionIncident incident);
}
