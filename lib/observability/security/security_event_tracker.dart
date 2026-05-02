import 'package:flutter_production_kit/observability/domain/entities/security_event.dart';
import 'package:flutter_production_kit/observability/domain/repositories/observability_repositories.dart';

/// Security event tracker — tracks security-critical events and anomalies.
///
/// Design rationale:
/// - All security events are immutable and auditable.
/// - Events are classified by type and severity.
/// - Anomaly scoring enables automated detection thresholds.
/// - High-risk events trigger immediate alerts.
/// - Integration with incident tracker for investigation.
///
/// Event flow:
///   1. Detect security event (login failure, permission escalation, etc.).
///   2. Classify event type and severity.
///   3. Compute anomaly score based on context.
///   4. Record event to repository.
///   5. If high-risk, trigger alert and create incident.
class SecurityEventTracker {
  SecurityEventTracker({
    required SecurityEventRepository securityEventRepository,
    List<AnomalyDetectionRule>? detectionRules,
  })  : _securityEventRepository = securityEventRepository,
        _detectionRules = detectionRules ?? _defaultRules;

  static const List<AnomalyDetectionRule> _defaultRules = [
    AnomalyDetectionRule(
      eventType: SecurityEventType.bruteForceAttempt,
      threshold: 5,
      windowMinutes: 10,
      severityBoost: 0.3,
    ),
    AnomalyDetectionRule(
      eventType: SecurityEventType.permissionEscalationAttempt,
      threshold: 1,
      windowMinutes: 60,
      severityBoost: 0.4,
    ),
    AnomalyDetectionRule(
      eventType: SecurityEventType.loginFromNewDevice,
      threshold: 3,
      windowMinutes: 30,
      severityBoost: 0.2,
    ),
  ];

  final SecurityEventRepository _securityEventRepository;
  final List<AnomalyDetectionRule> _detectionRules;
  final List<SecurityEvent> _recentEvents = [];

  /// Track a security event.
  Future<SecurityEvent> track({
    required SecurityEventType eventType,
    required SecurityEventSeverity severity,
    required String actorId,
    required String source,
    required String description,
    String? correlationId,
    double? anomalyScore,
    Map<String, String>? metadata,
    bool responseRequired = false,
  }) async {
    // Compute anomaly score.
    final computedScore = _computeAnomalyScore(
      eventType: eventType,
      actorId: actorId,
      baseScore: anomalyScore ?? 0.0,
    );

    final event = SecurityEvent(
      id: 'sec_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      eventType: eventType,
      severity: _boostSeverity(severity, computedScore),
      actorId: actorId,
      source: source,
      description: description,
      correlationId: correlationId,
      anomalyScore: computedScore,
      metadata: metadata ?? {},
      responseRequired: responseRequired || computedScore > 0.8,
    );

    // Persist.
    await _securityEventRepository.saveSecurityEvent(event);

    // Track for anomaly detection.
    _recentEvents.add(event);
    _cleanupOldEvents();

    return event;
  }

  /// Track a failed login attempt.
  Future<SecurityEvent> trackLoginFailed({
    required String actorId,
    required String source,
    String? correlationId,
    Map<String, String>? metadata,
  }) {
    return track(
      eventType: SecurityEventType.loginFailed,
      severity: SecurityEventSeverity.low,
      actorId: actorId,
      source: source,
      description: 'Failed login attempt',
      correlationId: correlationId,
      metadata: metadata,
    );
  }

  /// Track a brute force attempt (multiple failed logins).
  Future<SecurityEvent> trackBruteForce({
    required String actorId,
    required String source,
    required int attemptCount,
    String? correlationId,
  }) {
    return track(
      eventType: SecurityEventType.bruteForceAttempt,
      severity: SecurityEventSeverity.high,
      actorId: actorId,
      source: source,
      description: 'Brute force attempt detected ($attemptCount attempts)',
      correlationId: correlationId,
      responseRequired: true,
    );
  }

  /// Track a permission escalation attempt.
  Future<SecurityEvent> trackPermissionEscalation({
    required String actorId,
    required String source,
    required String requestedPermission,
    String? correlationId,
  }) {
    return track(
      eventType: SecurityEventType.permissionEscalationAttempt,
      severity: SecurityEventSeverity.critical,
      actorId: actorId,
      source: source,
      description: 'Permission escalation attempt: $requestedPermission',
      correlationId: correlationId,
      responseRequired: true,
    );
  }

  /// Track a manual override.
  Future<SecurityEvent> trackManualOverride({
    required String actorId,
    required String source,
    required String target,
    required String reason,
    String? correlationId,
  }) {
    return track(
      eventType: SecurityEventType.manualOverrideGranted,
      severity: SecurityEventSeverity.medium,
      actorId: actorId,
      source: source,
      description: 'Manual override granted: $target ($reason)',
      correlationId: correlationId,
      metadata: {'target': target, 'reason': reason},
    );
  }

  /// Get high-risk events.
  Future<List<SecurityEvent>> getHighRiskEvents() {
    return _securityEventRepository.getHighRiskEvents();
  }

  /// Get unacknowledged events.
  Future<List<SecurityEvent>> getUnacknowledgedEvents() {
    return _securityEventRepository.getUnacknowledgedEvents();
  }

  /// Get events by actor.
  Future<List<SecurityEvent>> getEventsByActor(String actorId) {
    return _securityEventRepository.getEventsByActor(actorId);
  }

  // ── Anomaly Detection ─────────────────────────────────────────────────────

  double _computeAnomalyScore({
    required SecurityEventType eventType,
    required String actorId,
    required double baseScore,
  }) {
    var score = baseScore;

    for (final rule in _detectionRules) {
      if (rule.eventType == eventType) {
        // Count recent events of this type for this actor.
        final count = _recentEvents
            .where((e) => e.eventType == eventType && e.actorId == actorId)
            .length;

        if (count >= rule.threshold) {
          score += rule.severityBoost;
        }
      }
    }

    return score.clamp(0.0, 1.0);
  }

  SecurityEventSeverity _boostSeverity(
    SecurityEventSeverity severity,
    double anomalyScore,
  ) {
    if (anomalyScore > 0.8 && severity.index < SecurityEventSeverity.critical.index) {
      return SecurityEventSeverity.critical;
    }
    if (anomalyScore > 0.6 && severity.index < SecurityEventSeverity.high.index) {
      return SecurityEventSeverity.high;
    }
    return severity;
  }

  void _cleanupOldEvents() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 30));
    _recentEvents.removeWhere((e) => e.timestamp.isBefore(cutoff));
  }
}

/// Anomaly detection rule — defines thresholds for anomaly scoring.
class AnomalyDetectionRule {
  const AnomalyDetectionRule({
    required this.eventType,
    required this.threshold,
    required this.windowMinutes,
    required this.severityBoost,
  });

  final SecurityEventType eventType;
  final int threshold;
  final int windowMinutes;
  final double severityBoost;
}
