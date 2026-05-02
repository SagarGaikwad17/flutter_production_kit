import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';

/// Grace period manager — manages the grace period lifecycle.
///
/// Design rationale:
/// - Grace period is a safety buffer after payment failure.
/// - User retains full access during grace period.
/// - Grace period duration is plan-specific.
/// - Tracks entry/exit for audit purposes.
/// - Supports tiered grace periods:
///   1. Soft grace (0-3 days): full access, payment retries.
///   2. Hard grace (3-7 days): full access, dunning emails.
///   3. Restricted (7+ days): limited access, downgrade suggested.
///
/// Grace period flow:
///   1. Payment fails → enter grace period.
///   2. During grace → retry payment on schedule.
///   3. Grace ends → transition to restricted_access.
///   4. Payment succeeds during grace → return to active.
class GracePeriodManager {
  const GracePeriodManager();

  /// Check if a subscription is in grace period.
  bool isInGracePeriod(SubscriptionState state) {
    return state is SubscriptionGracePeriod;
  }

  /// Get the grace period tier based on time elapsed.
  GracePeriodTier getTier(SubscriptionGracePeriod state) {
    final now = DateTime.now();
    final elapsed = now.difference(state.since).inDays;
    final total = state.graceEndsAt.difference(state.since).inDays;

    if (total <= 0) return GracePeriodTier.expired;

    final progress = elapsed / total;
    return switch (progress) {
      < 0.4 => GracePeriodTier.soft,
      < 0.7 => GracePeriodTier.hard,
      < 1.0 => GracePeriodTier.restricted,
      _ => GracePeriodTier.expired,
    };
  }

  /// Check if grace period has expired.
  bool isExpired(SubscriptionGracePeriod state) {
    return DateTime.now().isAfter(state.graceEndsAt);
  }

  /// Get days remaining in grace period.
  int getDaysRemaining(SubscriptionGracePeriod state) {
    final remaining = state.graceEndsAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Get recommended actions for current grace tier.
  List<String> getRecommendedActions(SubscriptionGracePeriod state) {
    final tier = getTier(state);
    return switch (tier) {
      GracePeriodTier.soft => const [
          'Retry payment with existing method.',
          'Send gentle payment reminder.',
        ],
      GracePeriodTier.hard => const [
          'Retry payment with alternative method.',
          'Send dunning email.',
          'Offer payment plan options.',
        ],
      GracePeriodTier.restricted => const [
          'Notify user of impending restriction.',
          'Suggest downgrade to free tier.',
          'Prepare restricted access transition.',
        ],
      GracePeriodTier.expired => const [
          'Transition to restricted access.',
          'Notify user of access change.',
        ],
    };
  }

  /// Check if payment retry should be attempted.
  bool shouldRetryPayment(SubscriptionGracePeriod state) {
    final tier = getTier(state);
    return tier != GracePeriodTier.expired;
  }
}

enum GracePeriodTier {
  soft,
  hard,
  restricted,
  expired,
}
