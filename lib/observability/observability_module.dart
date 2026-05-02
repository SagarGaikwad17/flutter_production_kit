import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/observability/alerts/critical_event_notifier.dart';
import 'package:flutter_production_kit/observability/audits/audit_trail_engine.dart';
import 'package:flutter_production_kit/observability/audits/immutable_audit_store.dart';
import 'package:flutter_production_kit/observability/diagnostics/failure_investigator.dart';
import 'package:flutter_production_kit/observability/diagnostics/production_diagnostics_engine.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';
import 'package:flutter_production_kit/observability/incidents/incident_tracker.dart';
import 'package:flutter_production_kit/observability/logging/log_context_manager.dart';
import 'package:flutter_production_kit/observability/logging/structured_logger.dart';
import 'package:flutter_production_kit/observability/policies/audit_policy.dart';
import 'package:flutter_production_kit/observability/retention/retention_manager.dart';
import 'package:flutter_production_kit/observability/security/anomaly_detection_hooks.dart';
import 'package:flutter_production_kit/observability/security/security_event_tracker.dart';
import 'package:flutter_production_kit/observability/tracing/correlation_id_manager.dart';
import 'package:flutter_production_kit/observability/tracing/trace_engine.dart';
import 'package:get_it/get_it.dart';

/// Observability module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All observability dependencies are registered here in one place.
/// - The StructuredLogger wraps the existing AppLogger for backward compatibility.
/// - The AuditTrailEngine ensures immutable audit recording.
/// - The TraceEngine manages distributed tracing across modules.
/// - The FailureInvestigator provides investigation templates for common failures.
/// - The ProductionDiagnosticsEngine aggregates all data for investigation.
///
/// Usage:
/// ```dart
/// ObservabilityModule.register(getIt,
///   auditRepository: myAuditRepo,
///   traceRepository: myTraceRepo,
///   logRepository: myLogRepo,
///   securityEventRepository: mySecurityRepo,
///   incidentRepository: myIncidentRepo,
/// );
///
/// // Later in code:
/// final structuredLogger = getIt<StructuredLogger>();
/// final auditTrailEngine = getIt<AuditTrailEngine>();
/// final traceEngine = getIt<TraceEngine>();
/// final failureInvestigator = getIt<FailureInvestigator>();
/// ```
abstract final class ObservabilityModule {
  ObservabilityModule._();

  static const String _tag = 'ObservabilityModule';

  static void register(
    GetIt getIt, {
    required AuditRepository auditRepository,
    required TraceRepository traceRepository,
    required LogRepository logRepository,
    required SecurityEventRepository securityEventRepository,
    required IncidentRepository incidentRepository,
    AuditPolicy? auditPolicy,
    double? logSampleRate,
    List<AnomalyDetectionHook>? anomalyHooks,
    CriticalEventObserver? criticalEventObserver,
  }) {
    AppLogger.info(_tag, 'Registering observability module...');

    // ── Context Management ───────────────────────────────────────────────────

    getIt.registerLazySingleton<LogContextManager>(
      () => LogContextManager(),
    );

    getIt.registerLazySingleton<CorrelationIdManager>(
      () => CorrelationIdManager(),
    );

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuditPolicy>(
      () => auditPolicy ?? const AuditPolicy(),
    );

    // ── Logging ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<StructuredLogger>(
      () => StructuredLogger(
        logRepository: logRepository,
        contextManager: getIt<LogContextManager>(),
        sampleRate: logSampleRate,
      ),
    );

    // ── Audit ────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ImmutableAuditStore>(
      () => ImmutableAuditStore(),
    );

    getIt.registerLazySingleton<AuditTrailEngine>(
      () => AuditTrailEngine(
        auditRepository: auditRepository,
        auditStore: getIt<ImmutableAuditStore>(),
      ),
    );

    // ── Tracing ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TraceEngine>(
      () => TraceEngine(
        traceRepository: traceRepository,
        correlationIdManager: getIt<CorrelationIdManager>(),
      ),
    );

    // ── Security ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SecurityEventTracker>(
      () => SecurityEventTracker(
        securityEventRepository: securityEventRepository,
        detectionRules: [],
      ),
    );

    // ── Incidents ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<IncidentTracker>(
      () => IncidentTracker(
        incidentRepository: incidentRepository,
      ),
    );

    // ── Diagnostics ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ProductionDiagnosticsEngine>(
      () => ProductionDiagnosticsEngine(
        traceRepository: traceRepository,
        auditRepository: auditRepository,
        securityEventRepository: securityEventRepository,
        incidentRepository: incidentRepository,
      ),
    );

    getIt.registerLazySingleton<FailureInvestigator>(
      () => FailureInvestigator(
        traceRepository: traceRepository,
        auditRepository: auditRepository,
        securityEventRepository: securityEventRepository,
      ),
    );

    // ── Retention ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RetentionManager>(
      () => RetentionManager(
        auditRepository: auditRepository,
        logRepository: logRepository,
        traceRepository: traceRepository,
        securityEventRepository: securityEventRepository,
      ),
    );

    // ── Alerts ───────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<CriticalEventObserver>(
      () => criticalEventObserver ?? const LoggingCriticalEventNotifier(),
    );

    AppLogger.info(_tag, 'Observability module registration complete.');
  }

  /// Unregister all observability dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<StructuredLogger>();
    getIt.unregister<LogContextManager>();
    getIt.unregister<CorrelationIdManager>();
    getIt.unregister<AuditTrailEngine>();
    getIt.unregister<ImmutableAuditStore>();
    getIt.unregister<TraceEngine>();
    getIt.unregister<SecurityEventTracker>();
    getIt.unregister<IncidentTracker>();
    getIt.unregister<ProductionDiagnosticsEngine>();
    getIt.unregister<FailureInvestigator>();
    getIt.unregister<RetentionManager>();
    getIt.unregister<CriticalEventObserver>();
    getIt.unregister<AuditPolicy>();

    AppLogger.info(_tag, 'Observability module unregistered.');
  }
}
