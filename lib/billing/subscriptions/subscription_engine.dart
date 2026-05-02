import 'package:flutter_production_kit/billing/domain/entities/billing_audit_entry.dart';
import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/billing/subscriptions/subscription_state_machine.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Subscription engine — central orchestrator for subscription lifecycle.
///
/// Design rationale:
/// - Manages the full subscription lifecycle through explicit state transitions.
/// - Coordinates between:
///   - SubscriptionRepository (persistence)
///   - SubscriptionStateMachine (transition validation)
///   - BillingAuditRepository (audit trail)
/// - All transitions are validated before execution.
/// - All transitions are audited for compliance.
/// - Returns typed BillingAccessResult for access checks.
///
/// Lifecycle flow:
///   1. Create subscription (trial or active).
///   2. Monitor payment events.
///   3. Transition on payment success/failure.
///   4. Enforce grace periods on failure.
///   5. Restrict access after grace expiry.
///   6. Suspend after restricted period.
///   7. Reactivate on payment recovery.
class SubscriptionEngine {
  SubscriptionEngine({
    required SubscriptionRepository subscriptionRepository,
    required BillingAuditRepository auditRepository,
    SubscriptionStateMachine? stateMachine,
  })  : _subscriptionRepository = subscriptionRepository,
        _auditRepository = auditRepository,
        _stateMachine = stateMachine ?? const SubscriptionStateMachine();

  static const String _tag = 'SubscriptionEngine';

  final SubscriptionRepository _subscriptionRepository;
  final BillingAuditRepository _auditRepository;
  final SubscriptionStateMachine _stateMachine;

  /// Create a new subscription (trial or active).
  Future<SubscriptionState> createSubscription({
    required String subscriptionId,
    required String userId,
    required PlanConfig plan,
    String? tenantId,
    bool startWithTrial = false,
    String? initiatedBy,
  }) async {
    final now = DateTime.now();

    final state = startWithTrial && plan.trialDays > 0
        ? SubscriptionTrial(
            since: now,
            trialEndsAt: now.add(Duration(days: plan.trialDays)),
            planId: plan.id,
          )
        : SubscriptionActive(
            since: now,
            currentPeriodStart: now,
            currentPeriodEnd: now.add(_billingPeriod(plan)),
            planId: plan.id,
            autoRenew: true,
          );

    await _subscriptionRepository.saveSubscription(state);
    await _auditRepository.saveAuditEntry(BillingAuditEntry(
      id: 'audit_${now.millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      eventType: startWithTrial ? 'trial_started' : 'subscription_created',
      fromState: 'none',
      toState: state.runtimeType.toString(),
      actedBy: initiatedBy ?? 'system',
      actedAt: now,
      reason: startWithTrial ? 'Trial activation' : 'New subscription',
    ));

    AppLogger.info(
      _tag,
      'Subscription created: $subscriptionId (${state.runtimeType})',
    );

    return state;
  }

  /// Activate a subscription (payment confirmed).
  Future<SubscriptionState> activateSubscription({
    required String subscriptionId,
    required String planId,
    String? paymentReference,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    final activeState = SubscriptionActive(
      since: now,
      currentPeriodStart: now,
      currentPeriodEnd: now.add(const Duration(days: 30)),
      planId: planId,
      autoRenew: true,
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: activeState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(_tag, 'Subscription activated: $subscriptionId');
    return newState;
  }

  /// Enter grace period (payment failed).
  Future<SubscriptionState> enterGracePeriod({
    required String subscriptionId,
    required int failedPaymentAttempts,
    String? paymentError,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    if (current is! SubscriptionActive && current is! SubscriptionPaymentPending) {
      throw InvalidSubscriptionTransitionException(
        message: 'Cannot enter grace period from ${current.runtimeType}.',
        currentState: current.runtimeType.toString(),
        requestedState: 'grace_period',
      );
    }

    final graceState = SubscriptionGracePeriod(
      since: now,
      graceEndsAt: now.add(const Duration(days: 7)),
      planId: current is SubscriptionActive ? current.planId : 'unknown',
      failedPaymentAttempts: failedPaymentAttempts,
      lastPaymentError: paymentError,
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: graceState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(
      _tag,
      'Grace period entered: $subscriptionId (attempts: $failedPaymentAttempts)',
    );

    return newState;
  }

  /// Enter restricted access (grace period expired).
  Future<SubscriptionState> enterRestrictedAccess({
    required String subscriptionId,
    required List<String> allowedActions,
    String? downgradePlanId,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    if (current is! SubscriptionGracePeriod) {
      throw InvalidSubscriptionTransitionException(
        message: 'Cannot enter restricted access from ${current.runtimeType}.',
        currentState: current.runtimeType.toString(),
        requestedState: 'restricted_access',
      );
    }

    if (DateTime.now().isBefore(current.graceEndsAt)) {
      throw InvalidSubscriptionTransitionException(
        message: 'Grace period has not yet expired.',
        currentState: 'grace_period',
        requestedState: 'restricted_access',
      );
    }

    final restrictedState = SubscriptionRestrictedAccess(
      since: now,
      planId: current.planId,
      restrictedSince: now,
      allowedActions: allowedActions,
      downgradePlanId: downgradePlanId,
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: restrictedState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(_tag, 'Restricted access: $subscriptionId');
    return newState;
  }

  /// Suspend subscription (restricted period expired).
  Future<SubscriptionState> suspendSubscription({
    required String subscriptionId,
    String? reason,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    if (current is! SubscriptionRestrictedAccess) {
      throw InvalidSubscriptionTransitionException(
        message: 'Cannot suspend from ${current.runtimeType}.',
        currentState: current.runtimeType.toString(),
        requestedState: 'suspended',
      );
    }

    final suspendedState = SubscriptionSuspended(
      since: now,
      planId: current.planId,
      suspendedSince: now,
      reason: reason ?? 'Restricted period expired',
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: suspendedState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(_tag, 'Subscription suspended: $subscriptionId');
    return newState;
  }

  /// Cancel subscription (user-initiated).
  Future<SubscriptionState> cancelSubscription({
    required String subscriptionId,
    required String cancelledBy,
    String? reason,
    DateTime? effectiveDate,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    if (current is! SubscriptionActive) {
      throw InvalidSubscriptionTransitionException(
        message: 'Cannot cancel from ${current.runtimeType}.',
        currentState: current.runtimeType.toString(),
        requestedState: 'cancelled',
      );
    }

    final cancelledState = SubscriptionCancelled(
      since: now,
      planId: current.planId,
      effectiveDate: effectiveDate ?? current.currentPeriodEnd,
      cancelledBy: cancelledBy,
      reason: reason,
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: cancelledState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(_tag, 'Subscription cancelled: $subscriptionId');
    return newState;
  }

  /// Grant manual override (admin access).
  Future<SubscriptionState> grantManualOverride({
    required String subscriptionId,
    required String grantedBy,
    required String reason,
    required Duration duration,
    List<String>? additionalEntitlements,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    final overrideState = SubscriptionManualOverrideActive(
      since: now,
      planId: current is SubscriptionActive ? current.planId : 'unknown',
      overrideGrantedBy: grantedBy,
      overrideExpiresAt: now.add(duration),
      overrideReason: reason,
      overrideEntitlements: additionalEntitlements ?? [],
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: overrideState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(
      _tag,
      'Manual override granted: $subscriptionId (expires: ${overrideState.overrideExpiresAt})',
    );

    return newState;
  }

  /// Revoke manual override.
  Future<SubscriptionState> revokeManualOverride({
    required String subscriptionId,
    required String revokedBy,
    String? reason,
    String? initiatedBy,
  }) async {
    final current = await _getSubscription(subscriptionId);
    final now = DateTime.now();

    if (current is! SubscriptionManualOverrideActive) {
      throw InvalidSubscriptionTransitionException(
        message: 'No manual override to revoke.',
        currentState: current.runtimeType.toString(),
        requestedState: 'active',
      );
    }

    // Return to active state.
    final activeState = SubscriptionActive(
      since: now,
      currentPeriodStart: now,
      currentPeriodEnd: now.add(const Duration(days: 30)),
      planId: current.planId,
      autoRenew: true,
    );

    final newState = _stateMachine.transition(
      currentState: current,
      nextState: activeState,
    );

    await _subscriptionRepository.updateSubscription(newState);
    await _auditTransition(subscriptionId, current, newState, initiatedBy);

    AppLogger.info(_tag, 'Manual override revoked: $subscriptionId');
    return newState;
  }

  /// Get subscription by ID.
  Future<SubscriptionState?> getSubscription(String subscriptionId) {
    return _subscriptionRepository.getSubscription(subscriptionId);
  }

  /// Get subscriptions for a user.
  Future<List<SubscriptionState>> getUserSubscriptions(String userId) {
    return _subscriptionRepository.getSubscriptionsForUser(userId);
  }

  /// Check if subscription is active.
  Future<bool> isSubscriptionActive(String subscriptionId) async {
    final sub = await _subscriptionRepository.getSubscription(subscriptionId);
    return sub?.isActive ?? false;
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  Future<SubscriptionState> _getSubscription(String id) async {
    final sub = await _subscriptionRepository.getSubscription(id);
    if (sub == null) {
      throw SubscriptionNotFoundException(
        message: 'Subscription not found: $id',
        subscriptionId: id,
      );
    }
    return sub;
  }

  Future<void> _auditTransition(
    String subscriptionId,
    SubscriptionState from,
    SubscriptionState to,
    String? initiatedBy,
  ) async {
    await _auditRepository.saveAuditEntry(BillingAuditEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      subscriptionId: subscriptionId,
      eventType: 'transition_${to.runtimeType.toString().split('.').last}',
      fromState: from.runtimeType.toString().split('.').last,
      toState: to.runtimeType.toString().split('.').last,
      actedBy: initiatedBy ?? 'system',
      actedAt: DateTime.now(),
    ));
  }

  Duration _billingPeriod(PlanConfig plan) {
    // Simplified — in production, use pricing model's billing cycle.
    return const Duration(days: 30);
  }
}
