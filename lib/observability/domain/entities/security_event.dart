/// Security event — tracks security-critical actions and anomalies.
///
/// Design rationale:
/// - All security events are immutable and auditable.
/// - [severity] determines response urgency.
/// - [eventType] categorizes the security concern.
/// - [actorId] identifies the source (user, system, unknown).
/// - [source] identifies where the event originated.
/// - NO sensitive data (passwords, tokens, PII).
/// - [anomalyScore] enables automated detection thresholds.
/// - [correlationId] links to related traces for investigation.
class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.actorId,
    required this.source,
    required this.description,
    this.correlationId,
    this.anomalyScore = 0.0,
    this.metadata = const {},
    this.responseRequired = false,
    this.responseStatus = SecurityEventResponseStatus.pending,
  });

  final String id;
  final DateTime timestamp;
  final SecurityEventType eventType;
  final SecurityEventSeverity severity;
  final String actorId;
  final String source;
  final String description;
  final String? correlationId;
  final double anomalyScore;
  final Map<String, String> metadata;
  final bool responseRequired;
  final SecurityEventResponseStatus responseStatus;

  bool isHighRisk() {
    return severity == SecurityEventSeverity.critical ||
        severity == SecurityEventSeverity.high ||
        anomalyScore > 0.8;
  }
}

enum SecurityEventType {
  /// Failed login attempt.
  loginFailed,

  /// Successful login from new device/location.
  loginFromNewDevice,

  /// Multiple failed logins (potential brute force).
  bruteForceAttempt,

  /// Session invalidated unexpectedly.
  sessionInvalidated,

  /// Token refresh failure.
  tokenRefreshFailed,

  /// Permission escalation attempt.
  permissionEscalationAttempt,

  /// Admin action performed.
  adminAction,

  /// Manual override granted.
  manualOverrideGranted,

  /// Manual override revoked.
  manualOverrideRevoked,

  /// Data export initiated.
  dataExportInitiated,

  /// Suspicious API usage pattern.
  suspiciousApiUsage,

  /// Offline sync anomaly detected.
  syncAnomaly,

  /// Billing manipulation attempt.
  billingManipulationAttempt,

  /// Compliance violation detected.
  complianceViolation,
}

enum SecurityEventSeverity {
  low,
  medium,
  high,
  critical,
}

enum SecurityEventResponseStatus {
  pending,
  acknowledged,
  resolved,
  falsePositive,
}
