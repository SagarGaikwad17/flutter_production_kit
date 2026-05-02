import 'package:flutter_production_kit/observability/domain/entities/production_incident.dart';

/// Critical event notifier — notifies observers of critical production events.
///
/// Design rationale:
/// - Notifiers are fire-and-forget — failures don't block operations.
/// - Multiple notifier types can be registered (logging, webhook, etc.).
/// - Only critical events (error/fatal/high-risk) trigger notifications.
/// - Notification includes correlation ID for investigation linking.
///
/// Notification flow:
///   1. Critical event detected (error, security incident, etc.).
///   2. Event is classified and scored.
///   3. If above threshold, notify all registered observers.
///   4. Notification includes context for investigation.
///   5. Observer handles notification (log, alert, webhook, etc.).
abstract class CriticalEventObserver {
  const CriticalEventObserver();

  /// Called when a critical event occurs.
  void onCriticalEvent({
    required String eventType,
    required String severity,
    required String description,
    String? correlationId,
    String? userId,
    String? module,
    Map<String, String>? metadata,
  });

  /// Called when a new incident is created.
  void onIncidentCreated({
    required String incidentId,
    required IncidentSeverity severity,
    required String title,
    String? correlationId,
  });
}

/// Default critical event notifier — logs all critical events.
class LoggingCriticalEventNotifier implements CriticalEventObserver {
  const LoggingCriticalEventNotifier();

  static const String _tag = 'CriticalEventNotifier';

  @override
  void onCriticalEvent({
    required String eventType,
    required String severity,
    required String description,
    String? correlationId,
    String? userId,
    String? module,
    Map<String, String>? metadata,
  }) {
    // In production, this would integrate with:
    // - Sentry, Crashlytics for error tracking
    // - PagerDuty, Opsgenie for incident alerts
    // - Slack, Teams for team notifications
    // - Email for compliance records
    final msg = '[CRITICAL] $eventType ($severity): $description '
        '[module: $module, user: $userId, correlation: $correlationId]';
    // ignore: avoid_print
    print('$_tag: $msg');
  }

  @override
  void onIncidentCreated({
    required String incidentId,
    required IncidentSeverity severity,
    required String title,
    String? correlationId,
  }) {
    final msg = '[INCIDENT] $incidentId ($severity): $title '
        '[correlation: $correlationId]';
    // ignore: avoid_print
    print('$_tag: $msg');
  }
}
