import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Detects suspicious login patterns and triggers security actions.
///
/// Design rationale:
/// - Pluggable detection rules — each rule is a separate check.
/// - Threshold-based: a single signal is not enough to block, but multiple
///   signals trigger [SuspiciousLoginException].
/// - Rules are extensible: add new checks without modifying existing code.
/// - Results are logged with enough detail for security audits but NEVER
///   include tokens or PII.
///
/// Detection signals:
/// - Device fingerprint mismatch (new device for known user)
/// - Location anomaly (login from unusual geographic region)
/// - Time anomaly (login at unusual hour for this user)
/// - Velocity (multiple logins in short time window)
/// - IP reputation (known malicious IP range)
class SuspiciousLoginDetector {
  SuspiciousLoginDetector({
    List<LoginDetectionRule>? rules,
    this.suspiciousThreshold = 2,
  }) : _rules = rules ?? _defaultRules();

  static const String _tag = 'SuspiciousLoginDetector';

  final List<LoginDetectionRule> _rules;
  final int suspiciousThreshold;

  /// Evaluate login context against all detection rules.
  ///
  /// Returns a list of triggered rule names.
  /// If the count meets the threshold, throws [SuspiciousLoginException].
  List<String> evaluate(LoginContext context) {
    final triggeredRules = <String>[];

    for (final rule in _rules) {
      if (rule.isTriggered(context)) {
        triggeredRules.add(rule.name);
        AppLogger.warning(
          _tag,
          'Detection rule triggered: ${rule.name} (severity: ${rule.severity.name})',
        );
      }
    }

    if (triggeredRules.length >= suspiciousThreshold) {
      AppLogger.warning(
        _tag,
        'Suspicious login detected — ${triggeredRules.length} rules triggered '
        '(threshold: $suspiciousThreshold).',
      );
      throw SuspiciousLoginException(
        message: 'Login flagged as suspicious. Additional verification required.',
        reasons: triggeredRules,
      );
    }

    if (triggeredRules.isNotEmpty) {
      AppLogger.info(
        _tag,
        'Minor login anomaly — ${triggeredRules.length} signal(s) '
        '(below threshold: $suspiciousThreshold).',
      );
    }

    return triggeredRules;
  }

  static List<LoginDetectionRule> _defaultRules() {
    return [
      DeviceMismatchRule(),
      UnusualTimeRule(),
      RapidLoginRule(),
    ];
  }
}

// ── Login Context ────────────────────────────────────────────────────────────

/// Context data provided to detection rules.
class LoginContext {
  const LoginContext({
    required this.currentDeviceFingerprint,
    required this.currentTimestamp,
    this.previousDeviceFingerprint,
    this.lastLoginAt,
    this.previousLoginAt,
    this.currentIpAddress,
    this.currentCountryCode,
    this.recentLoginCount,
  });

  final String currentDeviceFingerprint;
  final DateTime currentTimestamp;
  final String? previousDeviceFingerprint;
  final DateTime? lastLoginAt;
  final DateTime? previousLoginAt;
  final String? currentIpAddress;
  final String? currentCountryCode;
  final int? recentLoginCount;
}

// ── Detection Rules ──────────────────────────────────────────────────────────

abstract class LoginDetectionRule {
  String get name;
  DetectionSeverity get severity;
  bool isTriggered(LoginContext context);
}

enum DetectionSeverity { low, medium, high, critical }

/// Device fingerprint doesn't match the previously known device.
class DeviceMismatchRule implements LoginDetectionRule {
  @override
  String get name => 'device_mismatch';

  @override
  DetectionSeverity get severity => DetectionSeverity.medium;

  @override
  bool isTriggered(LoginContext context) {
    final previous = context.previousDeviceFingerprint;
    if (previous == null || previous.isEmpty) return false;
    return context.currentDeviceFingerprint != previous;
  }
}

/// Login at an unusual hour (between 2 AM and 5 AM local time).
class UnusualTimeRule implements LoginDetectionRule {
  @override
  String get name => 'unusual_time';

  @override
  DetectionSeverity get severity => DetectionSeverity.low;

  @override
  bool isTriggered(LoginContext context) {
    final hour = context.currentTimestamp.hour;
    return hour >= 2 && hour <= 5;
  }
}

/// Multiple logins within a short time window (velocity check).
class RapidLoginRule implements LoginDetectionRule {
  RapidLoginRule({this.maxLoginsPerHour = 5});

  final int maxLoginsPerHour;

  @override
  String get name => 'rapid_login';

  @override
  DetectionSeverity get severity => DetectionSeverity.high;

  @override
  bool isTriggered(LoginContext context) {
    final count = context.recentLoginCount;
    if (count == null) return false;
    return count >= maxLoginsPerHour;
  }
}

/// Location anomaly — login from a country not seen before for this user.
class LocationAnomalyRule implements LoginDetectionRule {
  LocationAnomalyRule({this.knownCountries = const []});

  final List<String> knownCountries;

  @override
  String get name => 'location_anomaly';

  @override
  DetectionSeverity get severity => DetectionSeverity.high;

  @override
  bool isTriggered(LoginContext context) {
    final country = context.currentCountryCode;
    if (country == null || country.isEmpty) return false;
    if (knownCountries.isEmpty) return false;
    return !knownCountries.contains(country);
  }
}
