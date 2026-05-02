import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';

/// Access policy — determines access level based on subscription state.
///
/// Design rationale:
/// - Maps subscription states to access levels.
/// - Configurable per-tenant access rules.
/// - Supports offline access tolerance.
/// - Returns typed access decisions.
class AccessPolicy {
  const AccessPolicy({
    this.allowOfflineAccess = true,
    this.offlineAccessTolerance = const Duration(hours: 24),
    this.blockedActionsForRestricted = const [
      'create_premium_resource',
      'export_data',
      'api_access',
    ],
  });

  /// Allow access when offline.
  final bool allowOfflineAccess;

  /// How long to tolerate offline before revalidation.
  final Duration offlineAccessTolerance;

  /// Actions blocked during restricted access.
  final List<String> blockedActionsForRestricted;

  /// Get access level for a subscription state.
  AccessLevel getAccessLevel(SubscriptionState state) {
    return switch (state) {
      SubscriptionActive() => AccessLevel.full,
      SubscriptionTrial() => AccessLevel.full,
      SubscriptionGracePeriod() => AccessLevel.full,
      SubscriptionPaymentPending() => AccessLevel.full,
      SubscriptionManualOverrideActive() => AccessLevel.full,
      SubscriptionRestrictedAccess() => AccessLevel.restricted,
      SubscriptionSuspended() => AccessLevel.blocked,
      SubscriptionCancelled() => AccessLevel.full,
      SubscriptionExpired() => AccessLevel.blocked,
    };
  }

  /// Check if access should be granted offline.
  bool shouldGrantOfflineAccess({
    required SubscriptionState state,
    required DateTime lastOnlineCheck,
  }) {
    if (!allowOfflineAccess) return false;
    if (!state.hasAccess) return false;

    final elapsed = DateTime.now().difference(lastOnlineCheck);
    return elapsed < offlineAccessTolerance;
  }
}

enum AccessLevel {
  full,
  restricted,
  blocked,
}
