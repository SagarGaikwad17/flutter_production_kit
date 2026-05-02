import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';

/// Subscription state machine — explicit, auditable state transitions.
///
/// Design rationale:
/// - Pure state machine — no side effects.
/// - All transitions are validated before execution.
/// - Invalid transitions throw InvalidSubscriptionTransitionException.
/// - Transition rules are centralized and deterministic.
/// - Every transition is logged by the audit manager (caller responsibility).
///
/// Transition matrix:
///   trial → active (trial converted)
///   trial → grace_period (trial payment setup failed)
///   trial → expired (trial ended, no payment method)
///   active → grace_period (payment failed)
///   active → payment_pending (renewal initiated)
///   active → cancelled (user cancelled)
///   active → manual_override_active (admin override)
///   grace_period → active (payment succeeded)
///   grace_period → restricted_access (grace expired)
///   payment_pending → active (payment confirmed)
///   payment_pending → grace_period (payment failed)
///   restricted_access → active (payment succeeded)
///   restricted_access → suspended (restricted period expired)
///   cancelled → expired (effective date reached)
///   suspended → active (payment succeeded)
///   suspended → expired (permanent suspension)
///   manual_override_active → active (override expired)
///   manual_override_active → grace_period (override expired, payment pending)
class SubscriptionStateMachine {
  const SubscriptionStateMachine();

  /// Transition to a new state — validates and returns the new state.
  SubscriptionState transition({
    required SubscriptionState currentState,
    required SubscriptionState nextState,
    String? reason,
  }) {
    _validateTransition(currentState, nextState, reason);
    return nextState;
  }

  /// Check if a transition is allowed.
  bool canTransition({
    required SubscriptionState currentState,
    required SubscriptionState nextState,
  }) {
    try {
      _validateTransition(currentState, nextState, null);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get allowed transitions from current state.
  List<String> allowedTransitions(SubscriptionState currentState) {
    return switch (currentState) {
      SubscriptionActive() => const [
          'grace_period',
          'payment_pending',
          'cancelled',
          'manual_override_active',
        ],
      SubscriptionTrial() => const [
          'active',
          'grace_period',
          'expired',
        ],
      SubscriptionGracePeriod() => const [
          'active',
          'restricted_access',
        ],
      SubscriptionPaymentPending() => const [
          'active',
          'grace_period',
        ],
      SubscriptionRestrictedAccess() => const [
          'active',
          'suspended',
        ],
      SubscriptionSuspended() => const [
          'active',
          'expired',
        ],
      SubscriptionCancelled() => const ['expired'],
      SubscriptionExpired() => const [],
      SubscriptionManualOverrideActive() => const [
          'active',
          'grace_period',
        ],
    };
  }

  void _validateTransition(
    SubscriptionState current,
    SubscriptionState next,
    String? reason,
  ) {
    final allowed = _allowedTargets(current);
    if (!allowed.contains(next.runtimeType)) {
      throw InvalidSubscriptionTransitionException(
        message: 'Invalid transition from ${current.runtimeType} '
            'to ${next.runtimeType}. Allowed: ${allowed.map((t) => t.toString().split('.').last).join(', ')}',
        currentState: current.runtimeType.toString(),
        requestedState: next.runtimeType.toString(),
      );
    }

    // Additional validations per transition.
    if (current is SubscriptionGracePeriod && next is SubscriptionRestrictedAccess) {
      if (DateTime.now().isBefore(current.graceEndsAt)) {
        throw InvalidSubscriptionTransitionException(
          message: 'Cannot transition to restricted_access before grace period ends.',
          currentState: 'grace_period',
          requestedState: 'restricted_access',
        );
      }
    }

    if (current is SubscriptionCancelled && next is SubscriptionExpired) {
      if (DateTime.now().isBefore(current.effectiveDate)) {
        throw InvalidSubscriptionTransitionException(
          message: 'Cannot transition to expired before cancellation effective date.',
          currentState: 'cancelled',
          requestedState: 'expired',
        );
      }
    }

    if (current is SubscriptionManualOverrideActive &&
        (next is SubscriptionActive || next is SubscriptionGracePeriod)) {
      if (DateTime.now().isBefore(current.overrideExpiresAt)) {
        // Allow early revocation — this is intentional.
      }
    }
  }

  List<Type> _allowedTargets(SubscriptionState state) {
    return switch (state) {
      SubscriptionActive() => const [
          SubscriptionGracePeriod,
          SubscriptionPaymentPending,
          SubscriptionCancelled,
          SubscriptionManualOverrideActive,
        ],
      SubscriptionTrial() => const [
          SubscriptionActive,
          SubscriptionGracePeriod,
          SubscriptionExpired,
        ],
      SubscriptionGracePeriod() => const [
          SubscriptionActive,
          SubscriptionRestrictedAccess,
        ],
      SubscriptionPaymentPending() => const [
          SubscriptionActive,
          SubscriptionGracePeriod,
        ],
      SubscriptionRestrictedAccess() => const [
          SubscriptionActive,
          SubscriptionSuspended,
        ],
      SubscriptionSuspended() => const [
          SubscriptionActive,
          SubscriptionExpired,
        ],
      SubscriptionCancelled() => const [SubscriptionExpired],
      SubscriptionExpired() => const [],
      SubscriptionManualOverrideActive() => const [
          SubscriptionActive,
          SubscriptionGracePeriod,
        ],
    };
  }
}
