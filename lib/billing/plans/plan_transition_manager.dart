import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/plans/plan_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Plan transition manager — orchestrates safe upgrades and downgrades.
///
/// Design rationale:
/// - Validates transition feasibility before execution.
/// - Computes proration for mid-cycle changes.
/// - Handles downgrade with active dependencies safely.
/// - Returns typed results for each transition scenario.
/// - Integrates with PlanManager for plan validation.
///
/// Upgrade flow:
///   1. Validate target plan exists and is higher tier.
///   2. Compute proration credit from current period.
///   3. Validate tenant/branch compatibility.
///   4. Return upgrade result with financial details.
///
/// Downgrade flow:
///   1. Validate target plan exists and is lower tier.
///   2. Check for active dependencies (premium-only resources).
///   3. Apply downgrade policy (immediate vs end-of-period).
///   4. Reconcile entitlements.
///   5. Return downgrade result with safety warnings.
class PlanTransitionManager {
  PlanTransitionManager({
    required PlanManager planManager,
  }) : _planManager = planManager;

  static const String _tag = 'PlanTransitionManager';

  final PlanManager _planManager;

  /// Evaluate an upgrade transition.
  Future<UpgradeResult> evaluateUpgrade({
    required String currentPlanId,
    required String targetPlanId,
    required DateTime currentPeriodEnd,
    String? tenantId,
  }) async {
    final currentPlan = await _planManager.getPlan(currentPlanId);
    final targetPlan = await _planManager.getPlan(targetPlanId);

    if (!targetPlan.isHigherThan(currentPlan.tier)) {
      throw PlanTransitionBlockedException(
        message: 'Target plan ${targetPlan.id} is not an upgrade.',
        currentPlanId: currentPlanId,
        targetPlanId: targetPlanId,
        reason: 'Target tier must be higher than current tier.',
      );
    }

    // Check tenant compatibility.
    if (tenantId != null && !targetPlan.allowedTenants.contains(tenantId)) {
      throw PlanTransitionBlockedException(
        message: 'Target plan not available for tenant: $tenantId',
        currentPlanId: currentPlanId,
        targetPlanId: targetPlanId,
        reason: 'Tenant not allowed on target plan.',
      );
    }

    // Compute proration.
    final proration = _computeProration(
      currentPlan: currentPlan,
      targetPlan: targetPlan,
      currentPeriodEnd: currentPeriodEnd,
    );

    // Entitlement changes.
    final addedEntitlements = targetPlan.entitlements
        .where((e) => !currentPlan.entitlements.contains(e))
        .toList();

    final result = UpgradeResult(
      currentPlanId: currentPlanId,
      targetPlanId: targetPlanId,
      prorationAmountCents: proration,
      addedEntitlements: addedEntitlements,
      removedEntitlements: const [],
      effectiveImmediately: true,
      warnings: const [],
    );

    AppLogger.info(
      _tag,
      'Upgrade evaluated: $currentPlanId → $targetPlanId (proration: $proration)',
    );

    return result;
  }

  /// Evaluate a downgrade transition.
  Future<DowngradeResult> evaluateDowngrade({
    required String currentPlanId,
    required String targetPlanId,
    required DateTime currentPeriodEnd,
    required List<String> activeEntitlements,
    String? tenantId,
  }) async {
    final currentPlan = await _planManager.getPlan(currentPlanId);
    final targetPlan = await _planManager.getPlan(targetPlanId);

    if (!targetPlan.isLowerThan(currentPlan.tier)) {
      throw PlanTransitionBlockedException(
        message: 'Target plan ${targetPlan.id} is not a downgrade.',
        currentPlanId: currentPlanId,
        targetPlanId: targetPlanId,
        reason: 'Target tier must be lower than current tier.',
      );
    }

    // Check for active dependencies — entitlements in use that target plan doesn't have.
    final lostEntitlements = activeEntitlements
        .where((e) => !targetPlan.entitlements.contains(e))
        .toList();

    final warnings = <String>[];
    if (lostEntitlements.isNotEmpty) {
      warnings.add(
        'Lost entitlements: ${lostEntitlements.join(', ')}. '
        'Resources depending on these will be restricted.',
      );
    }

    // Compute proration.
    final proration = _computeProration(
      currentPlan: currentPlan,
      targetPlan: targetPlan,
      currentPeriodEnd: currentPeriodEnd,
    );

    // Entitlement changes.
    final addedEntitlements = targetPlan.entitlements
        .where((e) => !currentPlan.entitlements.contains(e))
        .toList();

    final result = DowngradeResult(
      currentPlanId: currentPlanId,
      targetPlanId: targetPlanId,
      prorationAmountCents: proration,
      addedEntitlements: addedEntitlements,
      lostEntitlements: lostEntitlements,
      effectiveAtEndOfPeriod: true,
      warnings: warnings,
      requiresReconciliation: lostEntitlements.isNotEmpty,
    );

    AppLogger.info(
      _tag,
      'Downgrade evaluated: $currentPlanId → $targetPlanId '
      '(lost: ${lostEntitlements.length} entitlements)',
    );

    return result;
  }

  /// Compute proration amount for mid-cycle transition.
  int _computeProration({
    required PlanConfig currentPlan,
    required PlanConfig targetPlan,
    required DateTime currentPeriodEnd,
  }) {
    final now = DateTime.now();
    final daysRemaining = currentPeriodEnd.difference(now).inDays;
    final totalDays = currentPeriodEnd
        .subtract(const Duration(days: 30))
        .difference(now)
        .inDays
        .abs();

    if (totalDays <= 0) return 0;

    // Get monthly amounts from pricing models.
    final currentMonthly = _extractMonthlyAmount(currentPlan);
    final targetMonthly = _extractMonthlyAmount(targetPlan);

    // Daily rate difference.
    final dailyDiff = (targetMonthly - currentMonthly) / 30.0;
    final proration = (dailyDiff * daysRemaining).round();

    return proration;
  }

  int _extractMonthlyAmount(PlanConfig plan) {
    return switch (plan.pricing) {
      FlatPricing(:final amountCents) => amountCents,
      PerSeatPricing(:final amountPerSeatCents, :final minSeats) =>
        amountPerSeatCents * minSeats,
      UsageBasedPricing(:final baseAmountCents) => baseAmountCents,
    };
  }
}

/// Result of an upgrade evaluation.
class UpgradeResult {
  const UpgradeResult({
    required this.currentPlanId,
    required this.targetPlanId,
    required this.prorationAmountCents,
    required this.addedEntitlements,
    required this.removedEntitlements,
    required this.effectiveImmediately,
    this.warnings = const [],
  });

  final String currentPlanId;
  final String targetPlanId;
  final int prorationAmountCents;
  final List<String> addedEntitlements;
  final List<String> removedEntitlements;
  final bool effectiveImmediately;
  final List<String> warnings;
}

/// Result of a downgrade evaluation.
class DowngradeResult {
  const DowngradeResult({
    required this.currentPlanId,
    required this.targetPlanId,
    required this.prorationAmountCents,
    required this.addedEntitlements,
    required this.lostEntitlements,
    required this.effectiveAtEndOfPeriod,
    required this.warnings,
    required this.requiresReconciliation,
  });

  final String currentPlanId;
  final String targetPlanId;
  final int prorationAmountCents;
  final List<String> addedEntitlements;
  final List<String> lostEntitlements;
  final bool effectiveAtEndOfPeriod;
  final List<String> warnings;
  final bool requiresReconciliation;
}
