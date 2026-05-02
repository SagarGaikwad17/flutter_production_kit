import 'package:flutter_production_kit/permissions/domain/entities/temporary_permission.dart';

/// Policy for managing temporary (time-bound) elevated access.
///
/// Design rationale:
/// - Temporary permissions are time-limited and automatically expire.
/// - The policy controls when and how temporary permissions are evaluated.
/// - Expiring-soon warnings are generated 15 minutes before expiry.
/// - The policy enforces that expired permissions are NEVER granted.
class TemporaryAccessPolicy {
  const TemporaryAccessPolicy({
    this.warningThreshold = const Duration(minutes: 15),
    this.maxDuration = const Duration(hours: 8),
  });

  /// How long before expiry to start showing warnings.
  final Duration warningThreshold;

  /// Maximum duration for any temporary permission.
  final Duration maxDuration;

  /// Check if a temporary permission is valid and active.
  bool isValid(TemporaryPermission permission) {
    return permission.isActive && !permission.isExpired;
  }

  /// Check if a temporary permission is about to expire.
  bool isExpiringSoon(TemporaryPermission permission) {
    if (!permission.isActive) return false;
    return permission.timeRemaining <= warningThreshold;
  }

  /// Validate that a requested duration doesn't exceed the maximum.
  bool isDurationAllowed(Duration requested) {
    return requested <= maxDuration;
  }

  /// Calculate the effective expiry time (capped to max duration).
  DateTime calculateExpiry(DateTime grantedAt, Duration requested) {
    final capped = requested > maxDuration ? maxDuration : requested;
    return grantedAt.add(capped);
  }
}
