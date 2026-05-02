import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Billing observer — event-driven notifications for billing state changes.
///
/// Design rationale:
/// - Observers are notified of billing transitions.
/// - Used for: analytics, notifications, external system sync.
/// - Observers are fire-and-forget — failures don't block billing operations.
/// - Multiple observers can be registered.
abstract class BillingObserver {
  const BillingObserver();

  /// Called when a subscription state changes.
  void onSubscriptionStateChanged({
    required String subscriptionId,
    required SubscriptionState previousState,
    required SubscriptionState newState,
    String? initiatedBy,
  });

  /// Called when a billing event is processed.
  void onBillingEventProcessed({
    required String eventId,
    required BillingEventType eventType,
    required bool success,
    String? error,
  });

  /// Called when a payment fails.
  void onPaymentFailed({
    required String subscriptionId,
    required int attemptNumber,
    required String error,
  });

  /// Called when a payment succeeds.
  void onPaymentSucceeded({
    required String subscriptionId,
    required String paymentReference,
  });

  /// Called when an entitlement check fails.
  void onEntitlementCheckFailed({
    required String userId,
    required String entitlementKey,
    required String reason,
  });

  /// Called when a manual override is granted.
  void onManualOverrideGranted({
    required String subscriptionId,
    required String grantedBy,
    required DateTime expiresAt,
  });

  /// Called when a duplicate event is detected.
  void onDuplicateEventDetected({
    required String idempotencyKey,
    required BillingEventType eventType,
  });
}

/// Default billing observer — logs all events.
class LoggingBillingObserver implements BillingObserver {
  const LoggingBillingObserver();

  static const String _tag = 'BillingObserver';

  @override
  void onSubscriptionStateChanged({
    required String subscriptionId,
    required SubscriptionState previousState,
    required SubscriptionState newState,
    String? initiatedBy,
  }) {
    AppLogger.info(
      _tag,
      'Subscription state changed: $subscriptionId '
      '(${previousState.runtimeType} → ${newState.runtimeType})',
    );
  }

  @override
  void onBillingEventProcessed({
    required String eventId,
    required BillingEventType eventType,
    required bool success,
    String? error,
  }) {
    if (success) {
      AppLogger.info(_tag, 'Event processed: $eventId (${eventType.name})');
    } else {
      AppLogger.error(
        _tag,
        'Event failed: $eventId (${eventType.name})',
        error: error ?? 'Unknown error',
      );
    }
  }

  @override
  void onPaymentFailed({
    required String subscriptionId,
    required int attemptNumber,
    required String error,
  }) {
    AppLogger.warning(
      _tag,
      'Payment failed: $subscriptionId (attempt $attemptNumber) — $error',
    );
  }

  @override
  void onPaymentSucceeded({
    required String subscriptionId,
    required String paymentReference,
  }) {
    AppLogger.info(
      _tag,
      'Payment succeeded: $subscriptionId (ref: $paymentReference)',
    );
  }

  @override
  void onEntitlementCheckFailed({
    required String userId,
    required String entitlementKey,
    required String reason,
  }) {
    AppLogger.warning(
      _tag,
      'Entitlement check failed: $userId / $entitlementKey — $reason',
    );
  }

  @override
  void onManualOverrideGranted({
    required String subscriptionId,
    required String grantedBy,
    required DateTime expiresAt,
  }) {
    AppLogger.info(
      _tag,
      'Manual override granted: $subscriptionId by $grantedBy (expires: $expiresAt)',
    );
  }

  @override
  void onDuplicateEventDetected({
    required String idempotencyKey,
    required BillingEventType eventType,
  }) {
    AppLogger.warning(
      _tag,
      'Duplicate event: $idempotencyKey (${eventType.name})',
    );
  }
}
