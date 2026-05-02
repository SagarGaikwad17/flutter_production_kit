import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Plan manager — manages plan definitions and lookups.
///
/// Design rationale:
/// - Plans are immutable — changes create new versions.
/// - Plans are cached for fast entitlement lookups.
/// - Tenant-aware plan filtering.
/// - Plan validation before transitions.
class PlanManager {
  PlanManager({
    required PlanRepository planRepository,
  }) : _planRepository = planRepository;

  static const String _tag = 'PlanManager';

  final PlanRepository _planRepository;
  final Map<String, PlanConfig> _cache = {};

  /// Get a plan by ID.
  Future<PlanConfig> getPlan(String planId) async {
    if (_cache.containsKey(planId)) {
      return _cache[planId]!;
    }

    final plan = await _planRepository.getPlan(planId);
    if (plan == null) {
      throw PlanNotFoundException(
        message: 'Plan not found: $planId',
        planId: planId,
      );
    }

    _cache[planId] = plan;
    return plan;
  }

  /// Get all available plans.
  Future<List<PlanConfig>> getAllPlans() async {
    if (_cache.isEmpty) {
      final plans = await _planRepository.getAllPlans();
      for (final plan in plans) {
        _cache[plan.id] = plan;
      }
    }
    return _cache.values.toList();
  }

  /// Get plans available for a tenant.
  Future<List<PlanConfig>> getPlansForTenant(String tenantId) async {
    final plans = await _planRepository.getPlansForTenant(tenantId);
    for (final plan in plans) {
      _cache[plan.id] = plan;
    }
    return plans;
  }

  /// Get the default plan.
  Future<PlanConfig?> getDefaultPlan() async {
    final plans = await getAllPlans();
    for (final plan in plans) {
      if (plan.isDefault) return plan;
    }
    return null;
  }

  /// Check if a plan exists.
  Future<bool> hasPlan(String planId) async {
    if (_cache.containsKey(planId)) return true;
    final plan = await _planRepository.getPlan(planId);
    if (plan != null) _cache[planId] = plan;
    return plan != null;
  }

  /// Register a plan (admin operation).
  Future<void> registerPlan(PlanConfig plan) async {
    await _planRepository.savePlan(plan);
    _cache[plan.id] = plan;
    AppLogger.info(_tag, 'Plan registered: ${plan.id} (${plan.tier})');
  }

  /// Invalidate the plan cache.
  void invalidateCache() {
    _cache.clear();
  }

  /// Compare two plans — returns positive if planA > planB.
  int comparePlans(String planAId, String planBId) {
    final planA = _cache[planAId];
    final planB = _cache[planBId];
    if (planA == null || planB == null) return 0;
    return planA.tier.index - planB.tier.index;
  }
}
