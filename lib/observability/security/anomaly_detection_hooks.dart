import 'package:flutter_production_kit/observability/domain/entities/security_event.dart';

/// Anomaly detection hooks — pluggable hooks for custom anomaly detection.
///
/// Design rationale:
/// - Hooks are called when security events are tracked.
/// - Each hook can analyze the event and flag anomalies.
/// - Hooks are independent — one hook failure doesn't block others.
/// - Hooks can access historical context for pattern detection.
///
/// Built-in hooks:
///   - FrequencyHook: detects unusual event frequency.
///   - TimePatternHook: detects unusual timing patterns.
///   - GeoPatternHook: detects unusual location patterns.
///   - EntitlementHook: detects unusual entitlement changes.
abstract class AnomalyDetectionHook {
  const AnomalyDetectionHook();

  /// Analyze a security event and return an anomaly score (0.0 - 1.0).
  double analyze(SecurityEvent event);

  /// Get the hook name for logging.
  String get name;
}

/// Frequency anomaly detection hook.
class FrequencyAnomalyHook implements AnomalyDetectionHook {
  FrequencyAnomalyHook({
    this.threshold = 10,
    this.windowMinutes = 5,
  });

  final int threshold;
  final int windowMinutes;
  final Map<String, List<DateTime>> _eventTimes = {};

  @override
  String get name => 'frequency';

  @override
  double analyze(SecurityEvent event) {
    final key = '${event.actorId}:${event.eventType.name}';
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: windowMinutes));

    _eventTimes.putIfAbsent(key, () => []);
    _eventTimes[key]!.add(now);

    // Remove old events.
    _eventTimes[key]!.removeWhere((t) => t.isBefore(cutoff));

    final count = _eventTimes[key]!.length;
    if (count >= threshold) {
      return (count / (threshold * 2)).clamp(0.0, 1.0);
    }

    return 0.0;
  }
}

/// Time pattern anomaly detection hook.
class TimePatternAnomalyHook implements AnomalyDetectionHook {
  TimePatternAnomalyHook({
    this.normalHours = const [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  });

  final List<int> normalHours;

  @override
  String get name => 'time_pattern';

  @override
  double analyze(SecurityEvent event) {
    final hour = event.timestamp.hour;
    if (!normalHours.contains(hour)) {
      // Off-hours activity — moderate anomaly.
      return 0.4;
    }
    return 0.0;
  }
}

/// Entitlement change anomaly detection hook.
class EntitlementChangeAnomalyHook implements AnomalyDetectionHook {
  EntitlementChangeAnomalyHook({
    this.maxChangesPerHour = 3,
  });

  final int maxChangesPerHour;
  final Map<String, List<DateTime>> _changeTimes = {};

  @override
  String get name => 'entitlement_change';

  @override
  double analyze(SecurityEvent event) {
    if (event.eventType != SecurityEventType.manualOverrideGranted &&
        event.eventType != SecurityEventType.manualOverrideRevoked) {
      return 0.0;
    }

    final key = event.actorId;
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 1));

    _changeTimes.putIfAbsent(key, () => []);
    _changeTimes[key]!.add(now);
    _changeTimes[key]!.removeWhere((t) => t.isBefore(cutoff));

    final count = _changeTimes[key]!.length;
    if (count >= maxChangesPerHour) {
      return (count / (maxChangesPerHour * 2)).clamp(0.0, 1.0);
    }

    return 0.0;
  }
}
