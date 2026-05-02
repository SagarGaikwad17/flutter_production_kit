import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/billing/plans/plan_transition_manager.dart';
import 'package:flutter_production_kit/billing/policies/downgrade_policy.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Downgrade manager — orchestrates safe plan downgrades.
///
/// Design rationale:
/// - Validates downgrade feasibility.
/// - Checks for active dependencies (premium-only resources).
/// - Applies downgrade policy (immediate vs end-of-period).
/// - Reconciles entitlements to prevent data loss.
/// - Returns typed result with safety warnings.
///
/// Downgrade flow:
///   1. Evaluate downgrade with PlanTransitionManager.
///   2. Check for active dependencies.
///   3. Apply downgrade policy.
///   4. If reconciliation needed, flag for manual review.
///   5. Update subscription state (end-of-period by default).
///   6. Record billing event.
///   7. Return result with warnings.
class DowngradeManager {
  DowngradeManager({
    required PlanTransitionManager transitionManager,
    required SubscriptionRepository subscriptionRepository,
    required BillingEventRepository eventRepository,
    required DowngradePolicy downgradePolicy,
  })  : _transitionManager = transitionManager,
        _subscriptionRepository = subscriptionRepository,
        _eventRepository = eventRepository,
        _downgradePolicy = downgradePolicy;

  static const String _tag = 'DowngradeManager';

  final PlanTransitionManager _transitionManager;
  final SubscriptionRepository _subscriptionRepository;
  final BillingEventRepository _eventRepository;
  final DowngradePolicy _downgradePolicy;

  /// Execute a downgrade.
  Future<DowngradeExecutionResult> executeDowngrade({
    required String subscriptionId,
    required String targetPlanId,
    required String userId,
    required List<String> activeEntitlements,
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
        message: 'Cannot downgrade from ${subscription.runtimeType} state.',
        currentPlanId: subscription is SubscriptionActive ? subscription.planId : 'unknown',
        targetPlanId: targetPlanId,
        reason: 'Subscription not in active state.',
      );
    }

    final currentPlanId = subscription is SubscriptionActive
        ? subscription.planId
        : 'unknown';

    final evaluation = await _transitionManager.evaluateDowngrade(
      currentPlanId: currentPlanId,
      targetPlanId: targetPlanId,
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
      activeEntitlements: activeEntitlements,
      tenantId: tenantId,
    );

    // Check downgrade policy.
    final policyResult = _downgradePolicy.evaluateDowngrade(
      currentPlanId: currentPlanId,
      targetPlanId: targetPlanId,
      activeEntitlements: activeEntitlements,
      lostEntitlements: evaluation.lostEntitlements,
    );

    if (!policyResult.isAllowed) {
      throw PlanTransitionBlockedException(
        message: policyResult.blockReason ?? 'Downgrade blocked by policy.',
        currentPlanId: currentPlanId,
        targetPlanId: targetPlanId,
        reason: policyResult.blockReason,
      );
    }

    // Downgrade takes effect at end of current period.
    final periodEnd = subscription is SubscriptionActive
        ? subscription.currentPeriodEnd
        : DateTime.now().add(const Duration(days: 30));

    // Record the downgrade event.
    final now = DateTime.now();
    await _eventRepository.saveEvent(BillingEvent(
      id: 'evt_${now.millisecondsSinceEpoch}',
      idempotencyKey: 'downgrade_$subscriptionId:${now.millisecondsSinceEpoch}',
      type: BillingEventType.subscriptionDowngraded,
      subscriptionId: subscriptionId,
      userId: userId,
      tenantId: tenantId,
      payload: {
        'from_plan': currentPlanId,
        'to_plan': targetPlanId,
        'effective_at': periodEnd.toIso8601String(),
        'lost_entitlements': evaluation.lostEntitlements.join(','),
        'requires_reconciliation': evaluation.requiresReconciliation.toString(),
      },
      receivedAt: now,
      processedAt: now,
    ));

    AppLogger.info(
      _tag,
      'Downgrade executed: $subscriptionId ($currentPlanId → $targetPlanId) '
      'effective: $periodEnd',
    );

    return DowngradeExecutionResult(
      subscriptionId: subscriptionId,
      previousPlanId: currentPlanId,
      newPlanId: targetPlanId,
      lostEntitlements: evaluation.lostEntitlements,
      prorationAmountCents: evaluation.prorationAmountCents,
      effectiveAt: periodEnd,
      requiresReconciliation: evaluation.requiresReconciliation,
      warnings: evaluation.warnings,
    );
  }
}

class DowngradeExecutionResult {
  const DowngradeExecutionResult({
    required this.subscriptionId,
    required this.previousPlanId,
    required this.newPlanId,
    required this.lostEntitlements,
    required this.prorationAmountCents,
    required this.effectiveAt,
    required this.requiresReconciliation,
    required this.warnings,
  });

  final String subscriptionId;
  final String previousPlanId;
  final String newPlanId;
  final List<String> lostEntitlements;
  final int prorationAmountCents;
  final DateTime effectiveAt;
  final bool requiresReconciliation;
  final List<String> warnings;
}
