import 'package:flutter_production_kit/billing/domain/entities/billing_access_result.dart';
import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/billing/entitlements/feature_mapping_engine.dart';

/// Entitlement engine — resolves feature access based on billing state.
///
/// Design rationale:
/// - Central access decision point for all entitlement checks.
/// - Multi-layer resolution:
///   1. Check subscription state (active, grace, restricted, etc.).
///   2. Check plan entitlements (features granted by plan).
///   3. Check manual overrides (admin-granted access).
///   4. Check tenant/branch restrictions.
///   5. Check feature policy overrides (runtime kill switches).
/// - Returns typed BillingAccessResult — never a bool.
/// - Integrates with FeatureMappingEngine for feature-to-entitlement mapping.
///
/// Access resolution order:
///   1. Manual override (highest priority) — admin-granted access.
///   2. Subscription state — active/grace/trial = access.
///   3. Plan entitlements — feature must be in plan's entitlement list.
///   4. Tenant restriction — tenant must be allowed on plan.
///   5. Feature policy — runtime kill switch can block any feature.
class EntitlementEngine {
  EntitlementEngine({
    required SubscriptionRepository subscriptionRepository,
    required PlanRepository planRepository,
    required FeatureMappingEngine featureMappingEngine,
    this.defaultTenant,
  })  : _subscriptionRepository = subscriptionRepository,
        _planRepository = planRepository,
        _featureMappingEngine = featureMappingEngine;

  final SubscriptionRepository _subscriptionRepository;
  final PlanRepository _planRepository;
  final FeatureMappingEngine _featureMappingEngine;
  final String? defaultTenant;

  /// Check access for a specific feature/entitlement.
  Future<BillingAccessResult> checkAccess({
    required String entitlementKey,
    required String userId,
    String? subscriptionId,
    String? tenantId,
    String? branchId,
    bool isOnline = true,
  }) async {
    final resolvedTenant = tenantId ?? defaultTenant;

    // Step 1: Get subscription.
    final subscription = await _resolveSubscription(userId, subscriptionId);
    if (subscription == null) {
      return BillingAccessBlockedMissingEntitlement(
        entitlementKey: entitlementKey,
        planId: 'none',
        requiredEntitlement: entitlementKey,
        reason: 'No active subscription.',
      );
    }

    // Step 2: Check manual override (highest priority).
    if (subscription is SubscriptionManualOverrideActive) {
      if (DateTime.now().isAfter(subscription.overrideExpiresAt)) {
        // Override expired — treat as normal subscription check.
      } else {
        // Check if entitlement is in override list or base plan.
        if (subscription.overrideEntitlements.contains(entitlementKey)) {
          return BillingAccessGrantedManualOverride(
            entitlementKey: entitlementKey,
            planId: subscription.planId,
            overrideGrantedBy: subscription.overrideGrantedBy,
            overrideExpiresAt: subscription.overrideExpiresAt,
            overrideReason: subscription.overrideReason,
          );
        }
      }
    }

    // Step 3: Check subscription state.
    if (!subscription.hasAccess) {
      return _blockedByState(subscription, entitlementKey);
    }

    // Step 4: Get plan and check entitlements.
    final plan = await _planRepository.getPlan(
      subscription is SubscriptionActive
          ? subscription.planId
          : 'unknown',
    );

    if (plan == null) {
      return BillingAccessBlockedMissingEntitlement(
        entitlementKey: entitlementKey,
        planId: 'unknown',
        requiredEntitlement: entitlementKey,
        reason: 'Plan not found.',
      );
    }

    // Step 5: Check tenant restriction.
    if (resolvedTenant != null && !plan.allowedTenants.contains(resolvedTenant)) {
      return BillingAccessBlockedTenantMismatch(
        entitlementKey: entitlementKey,
        planId: plan.id,
        userTenant: resolvedTenant,
        allowedTenants: plan.allowedTenants,
      );
    }

    // Step 6: Check feature policy (runtime kill switch).
    if (_featureMappingEngine.isFeatureKilled(entitlementKey)) {
      return BillingAccessBlockedMissingEntitlement(
        entitlementKey: entitlementKey,
        planId: plan.id,
        requiredEntitlement: entitlementKey,
        reason: 'Feature killed by policy.',
      );
    }

    // Step 7: Check plan entitlements.
    if (plan.hasEntitlement(entitlementKey)) {
      return _grantedByPlan(subscription, plan, entitlementKey);
    }

    // Not entitled.
    return BillingAccessBlockedMissingEntitlement(
      entitlementKey: entitlementKey,
      planId: plan.id,
      requiredEntitlement: entitlementKey,
      reason: 'Entitlement not included in plan.',
    );
  }

  /// Check access for multiple features at once.
  Future<Map<String, BillingAccessResult>> checkAccessBatch({
    required List<String> entitlementKeys,
    required String userId,
    String? subscriptionId,
    String? tenantId,
  }) async {
    final results = <String, BillingAccessResult>{};

    for (final key in entitlementKeys) {
      results[key] = await checkAccess(
        entitlementKey: key,
        userId: userId,
        subscriptionId: subscriptionId,
        tenantId: tenantId,
      );
    }

    return results;
  }

  /// Get all entitlements for a user.
  Future<List<String>> getUserEntitlements({
    required String userId,
    String? subscriptionId,
    String? tenantId,
  }) async {
    final subscription = await _resolveSubscription(userId, subscriptionId);
    if (subscription == null || !subscription.hasAccess) {
      return const [];
    }

    if (subscription is SubscriptionManualOverrideActive &&
        DateTime.now().isBefore(subscription.overrideExpiresAt)) {
      final baseEntitlements = await _getPlanEntitlements(subscription.planId);
      return {
        ...baseEntitlements,
        ...subscription.overrideEntitlements,
      }.toList();
    }

    if (subscription is SubscriptionActive) {
      return _getPlanEntitlements(subscription.planId);
    }

    return [];
  }

  /// Check if user has a specific entitlement.
  Future<bool> hasEntitlement({
    required String entitlementKey,
    required String userId,
    String? subscriptionId,
    String? tenantId,
  }) async {
    final result = await checkAccess(
      entitlementKey: entitlementKey,
      userId: userId,
      subscriptionId: subscriptionId,
      tenantId: tenantId,
    );
    return result.isGranted;
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  Future<SubscriptionState?> _resolveSubscription(
    String userId,
    String? subscriptionId,
  ) async {
    if (subscriptionId != null) {
      return _subscriptionRepository.getSubscription(subscriptionId);
    }

    final subscriptions =
        await _subscriptionRepository.getSubscriptionsForUser(userId);
    if (subscriptions.isEmpty) return null;

    // Return the most recently active subscription.
    return subscriptions.firstWhere(
      (s) => s.hasAccess,
      orElse: () => subscriptions.first,
    );
  }

  BillingAccessResult _grantedByPlan(
    SubscriptionState subscription,
    PlanConfig plan,
    String entitlementKey,
  ) {
    if (subscription is SubscriptionTrial) {
      return BillingAccessGrantedTrial(
        entitlementKey: entitlementKey,
        planId: subscription.planId,
        trialEndsAt: subscription.trialEndsAt,
      );
    }

    if (subscription is SubscriptionGracePeriod) {
      return BillingAccessGrantedGracePeriod(
        entitlementKey: entitlementKey,
        planId: subscription.planId,
        graceEndsAt: subscription.graceEndsAt,
        failedPaymentAttempts: subscription.failedPaymentAttempts,
      );
    }

    return BillingAccessGranted(
      entitlementKey: entitlementKey,
      planId: plan.id,
      planTier: plan.tier.name,
    );
  }

  BillingAccessResult _blockedByState(
    SubscriptionState subscription,
    String entitlementKey,
  ) {
    return switch (subscription) {
      SubscriptionExpired() => BillingAccessBlockedExpired(
          entitlementKey: entitlementKey,
          planId: subscription.planId,
          expiredAt: subscription.expiredAt,
          reason: 'Subscription expired.',
        ),
      SubscriptionSuspended() => BillingAccessBlockedSuspended(
          entitlementKey: entitlementKey,
          planId: subscription.planId,
          suspendedSince: subscription.suspendedSince,
          reason: 'Subscription suspended.',
        ),
      SubscriptionRestrictedAccess() => BillingAccessRestricted(
          entitlementKey: entitlementKey,
          planId: subscription.planId,
          allowedActions: subscription.allowedActions,
          reason: 'Restricted access — grace period expired.',
          downgradePlanId: subscription.downgradePlanId,
        ),
      _ => BillingAccessBlockedMissingEntitlement(
          entitlementKey: entitlementKey,
          planId: 'unknown',
          requiredEntitlement: entitlementKey,
          reason: 'Subscription in non-access state: ${subscription.runtimeType}',
        ),
    };
  }

  Future<List<String>> _getPlanEntitlements(String planId) async {
    final plan = await _planRepository.getPlan(planId);
    return plan?.entitlements ?? [];
  }
}
