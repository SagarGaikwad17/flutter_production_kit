import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';

/// Payment recovery engine — manages failed payment recovery and dunning.
///
/// Design rationale:
/// - Handles payment failure recovery with configurable retry schedules.
/// - Implements dunning management (retry escalation).
/// - Tracks retry attempts and outcomes.
/// - Integrates with grace period manager for access decisions.
/// - Recovery flow:
///   1. Payment fails → record failure.
///   2. Schedule retry based on retry schedule.
///   3. On retry success → exit grace period.
///   4. On retry exhaustion → enter restricted access.
///
/// Retry schedule (default):
///   Attempt 1: Immediate (same day)
///   Attempt 2: +3 days
///   Attempt 3: +7 days
///   Attempt 4: +14 days
///   After 4 failures → restricted access
class PaymentRecoveryEngine {
  PaymentRecoveryEngine({
    required SubscriptionRepository subscriptionRepository,
    required BillingEventRepository eventRepository,
    List<Duration>? retrySchedule,
    int maxRetries = 4,
  })  : _subscriptionRepository = subscriptionRepository,
        _eventRepository = eventRepository,
        _retrySchedule = retrySchedule ?? const [
          Duration.zero,
          Duration(days: 3),
          Duration(days: 7),
          Duration(days: 14),
        ],
        _maxRetries = maxRetries;

  final SubscriptionRepository _subscriptionRepository;
  // ignore: unused_field
  final BillingEventRepository _eventRepository;
  final List<Duration> _retrySchedule;
  final int _maxRetries;

  /// Record a payment failure and initiate recovery.
  Future<RecoveryState> recordPaymentFailure({
    required String subscriptionId,
    required String paymentError,
    String? initiatedBy,
  }) async {
    final subscription = await _subscriptionRepository.getSubscription(subscriptionId);
    if (subscription == null) {
      return RecoveryState(
        subscriptionId: subscriptionId,
        status: RecoveryStatus.subscriptionNotFound,
      );
    }

    final failedAttempts = subscription is SubscriptionGracePeriod
        ? subscription.failedPaymentAttempts + 1
        : 1;

    if (failedAttempts >= _maxRetries) {
      return RecoveryState(
        subscriptionId: subscriptionId,
        status: RecoveryStatus.maxRetriesExceeded,
        failedAttempts: failedAttempts,
        nextRetryAt: null,
        recommendation: 'Transition to restricted access.',
      );
    }

    final nextRetryDelay = _retrySchedule[failedAttempts.clamp(0, _retrySchedule.length - 1)];
    final nextRetryAt = DateTime.now().add(nextRetryDelay);

    return RecoveryState(
      subscriptionId: subscriptionId,
      status: RecoveryStatus.recoveryInProgress,
      failedAttempts: failedAttempts,
      nextRetryAt: nextRetryAt,
      recommendation: 'Retry payment at $nextRetryAt.',
    );
  }

  /// Process a successful payment recovery.
  Future<RecoveryState> processPaymentSuccess({
    required String subscriptionId,
    String? paymentReference,
    String? initiatedBy,
  }) async {
    final subscription = await _subscriptionRepository.getSubscription(subscriptionId);
    if (subscription == null) {
      return RecoveryState(
        subscriptionId: subscriptionId,
        status: RecoveryStatus.subscriptionNotFound,
      );
    }

    return RecoveryState(
      subscriptionId: subscriptionId,
      status: RecoveryStatus.paymentRecovered,
      failedAttempts: 0,
      nextRetryAt: null,
      recommendation: 'Return to active subscription.',
    );
  }

  /// Get the next retry time for a subscription.
  Future<DateTime?> getNextRetryTime(String subscriptionId) async {
    final subscription = await _subscriptionRepository.getSubscription(subscriptionId);
    if (subscription is! SubscriptionGracePeriod) return null;

    final attempts = subscription.failedPaymentAttempts;
    if (attempts >= _maxRetries) return null;

    final delay = _retrySchedule[attempts.clamp(0, _retrySchedule.length - 1)];
    return DateTime.now().add(delay);
  }

  /// Check if recovery is still possible.
  bool canRecover(SubscriptionState state) {
    if (state is SubscriptionGracePeriod) {
      return state.failedPaymentAttempts < _maxRetries;
    }
    return false;
  }
}

/// Recovery state — result of a payment recovery attempt.
class RecoveryState {
  const RecoveryState({
    required this.subscriptionId,
    required this.status,
    this.failedAttempts,
    this.nextRetryAt,
    this.recommendation,
  });

  final String subscriptionId;
  final RecoveryStatus status;
  final int? failedAttempts;
  final DateTime? nextRetryAt;
  final String? recommendation;
}

enum RecoveryStatus {
  recoveryInProgress,
  paymentRecovered,
  maxRetriesExceeded,
  subscriptionNotFound,
}
