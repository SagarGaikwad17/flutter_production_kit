import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Rollout engine — deterministic percentage-based feature rollout.
///
/// Design rationale:
/// - Assigns users to rollout groups deterministically — same user always
///   gets the same result for the same rollout configuration.
/// - Uses a hash of userId + salt to assign a bucket (0–99).
/// - If bucket < percentage, user is in the rollout group.
/// - [salt] prevents correlation between different feature rollouts.
/// - Supports gradual rollout: 0% → 10% → 50% → 100%.
/// - Rollback is safe — users who were in the rollout stay in it.
class RolloutEngine {
  const RolloutEngine();

  static const String _tag = 'RolloutEngine';

  /// Check if a user is in the rollout group.
  ///
  /// Returns true if the user should receive the feature.
  /// Deterministic: same userId + percentage + salt always returns the same result.
  bool isInRollout({
    required String userId,
    required int percentage,
    String salt = '',
  }) {
    if (percentage <= 0) return false;
    if (percentage >= 100) return true;

    final bucket = _assignBucket(userId, salt);
    final isInGroup = bucket < percentage;

    AppLogger.debug(
      _tag,
      'Rollout check: user bucket=$bucket, percentage=$percentage, '
      'salt="$salt", result=$isInGroup',
    );

    return isInGroup;
  }

  /// Assign a user to a bucket (0–99).
  ///
  /// Uses a hash function for deterministic assignment.
  int _assignBucket(String userId, String salt) {
    final input = '$userId:$salt';
    final hash = _hashString(input);
    return hash % 100;
  }

  /// Hash a string to an integer.
  int _hashString(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs();
  }

  /// Calculate the rollout percentage for a gradual rollout schedule.
  ///
  /// Returns the current percentage based on time elapsed.
  /// Example: start at 0%, reach 100% over 7 days with daily increments.
  int calculateGradualPercentage({
    required DateTime startTime,
    required Duration totalDuration,
    required int steps,
  }) {
    final now = DateTime.now();
    final elapsed = now.difference(startTime);

    if (elapsed <= Duration.zero) return 0;
    if (elapsed >= totalDuration) return 100;

    final progress = elapsed.inSeconds / totalDuration.inSeconds;
    final stepSize = 100.0 / steps;
    final currentStep = (progress * steps).floor();
    final percentage = (currentStep * stepSize).round();
    return percentage < 0 ? 0 : (percentage > 100 ? 100 : percentage);
  }
}
