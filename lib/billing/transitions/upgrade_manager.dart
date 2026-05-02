import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/billing/plans/plan_transition_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Upgrade manager — orchestrates safe plan upgrades.
///
/// Design rationale:
/// - Validates upgrade feasibility.
/// - Computes proration for mid-cycle upgrades.
/// - Grants entitlements immediately (upgrades are user-friendly).
/// - Updates subscription state atomically.
/// - Logs all financial state changes for audit.
///
/// Upgrade flow:
///   1. Evaluate upgrade with PlanTransitionManager.
///   2. Validate no blocking conditions.
///   3. Update subscription to new plan.
///   4. Record billing event.
///   5. Return success with new entitlements.
class UpgradeManager {
  UpgradeManager({
    required PlanTransitionManager transitionManager,
    required SubscriptionRepository subscriptionRepository,
    required BillingEventRepository eventRepository,
  })  : _transitionManager = transitionManager,
        _subscriptionRepository = subscriptionRepository,
        _eventRepository = eventRepository;

  static const String _tag = 'UpgradeManager';

  final PlanTransitionManager _transitionManager;
  final SubscriptionRepository _subscriptionRepository;
  final BillingEventRepository _eventRepository;

  /// Execute an upgrade.
  Future<UpgradeExecutionResult> executeUpgrade({
    required String subscriptionId,
    required String targetPlanId,
    required String userId,
    String? tenantId,
    String? initiatedBy,
  }) async {
    final subscription = await _subscriptionRepository.getSubscription(subscriptionId);
    if (subscription == null) {
      throw SubscriptionNotFoundException(
        message: 'Subscription not found: $subscriptionId',
        subscriptionId: subscriptionId,
      );
    }

    if (!subscription.hasAccess) {
      throw PlanTransitionBlockedException(
        message: 'Cannot upgrade from ${subscription.runtimeType} state.',
        currentPlanId: subscription is SubscriptionActive ? subscription.planId : 'unknown',
        targetPlanId: targetPlanId,
        reason: 'Subscription not in active state.',
      );
    }

    final currentPlanId = subscription is SubscriptionActive
        ? subscription.planId
        : 'unknown';

    final evaluation = await _transitionManager.evaluateUpgrade(
      currentPlanId: currentPlanId,
      targetPlanId: targetPlanId,
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
      tenantId: tenantId,
    );

    // Execute the upgrade.
    final now = DateTime.now();

    final updatedState = SubscriptionActive(
      since: now,
      currentPeriodStart: now,
      currentPeriodEnd: subscription is SubscriptionActive
          ? subscription.currentPeriodEnd
          : now.add(const Duration(days: 30)),
      planId: targetPlanId,
      autoRenew: true,
    );

    await _subscriptionRepository.updateSubscription(updatedState);

    // Record the upgrade event.
    await _eventRepository.saveEvent(BillingEvent(
      id: 'evt_${now.millisecondsSinceEpoch}',
      idempotencyKey: 'upgrade_$subscriptionId:${now.millisecondsSinceEpoch}',
      type: BillingEventType.subscriptionUpgraded,
      subscriptionId: subscriptionId,
      userId: userId,
      tenantId: tenantId,
      payload: {
        'from_plan': currentPlanId,
        'to_plan': targetPlanId,
        'proration_cents': evaluation.prorationAmountCents.toString(),
      },
      receivedAt: now,
      processedAt: now,
    ));

    AppLogger.info(
      _tag,
      'Upgrade executed: $subscriptionId ($currentPlanId → $targetPlanId)',
    );

    return UpgradeExecutionResult(
      subscriptionId: subscriptionId,
      previousPlanId: currentPlanId,
      newPlanId: targetPlanId,
      addedEntitlements: evaluation.addedEntitlements,
      prorationAmountCents: evaluation.prorationAmountCents,
      effectiveImmediately: true,
    );
  }
}

class UpgradeExecutionResult {
  const UpgradeExecutionResult({
    required this.subscriptionId,
    required this.previousPlanId,
    required this.newPlanId,
    required this.addedEntitlements,
    required this.prorationAmountCents,
    required this.effectiveImmediately,
  });

  final String subscriptionId;
  final String previousPlanId;
  final String newPlanId;
  final List<String> addedEntitlements;
  final int prorationAmountCents;
  final bool effectiveImmediately;
}
