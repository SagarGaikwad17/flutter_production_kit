/// Plan configuration — defines a subscription plan.
///
/// Design rationale:
/// - [id] is the stable plan identifier.
/// - [tier] determines the plan level (free, basic, professional, enterprise).
/// - [entitlements] maps to feature keys the plan grants access to.
/// - [pricing] defines the billing model (flat, per-seat, usage-based).
/// - [limits] enforces usage caps (storage, API calls, users).
/// - [trialDays] enables trial conversion.
/// - [gracePeriodDays] defines payment failure tolerance.
/// - [restrictedActions] defines what's blocked in restricted_access state.
///
/// Plans are immutable. Changes create new plan versions.
class PlanConfig {
  const PlanConfig({
    required this.id,
    required this.name,
    required this.tier,
    required this.entitlements,
    required this.pricing,
    required this.limits,
    required this.allowedTenants,
    this.description,
    this.trialDays = 0,
    this.gracePeriodDays = 7,
    this.restrictedPeriodDays = 14,
    this.isDefault = false,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final String? description;
  final PlanTier tier;
  final List<String> entitlements;
  final PricingModel pricing;
  final PlanLimits limits;
  final List<String> allowedTenants;
  final int trialDays;
  final int gracePeriodDays;
  final int restrictedPeriodDays;
  final bool isDefault;
  final Map<String, String> metadata;

  bool hasEntitlement(String key) => entitlements.contains(key);

  bool isHigherThan(PlanTier other) => tier.index > other.index;

  bool isLowerThan(PlanTier other) => tier.index < other.index;
}

enum PlanTier { free, basic, professional, enterprise }

/// Pricing model — how the plan is billed.
sealed class PricingModel {
  const PricingModel({required this.currency});
  final String currency;
}

final class FlatPricing extends PricingModel {
  const FlatPricing({
    required super.currency,
    required this.amountCents,
    this.billingCycle = BillingCycle.monthly,
  });

  final int amountCents;
  final BillingCycle billingCycle;
}

final class PerSeatPricing extends PricingModel {
  const PerSeatPricing({
    required super.currency,
    required this.amountPerSeatCents,
    required this.minSeats,
    this.maxSeats,
    this.billingCycle = BillingCycle.monthly,
  });

  final int amountPerSeatCents;
  final int minSeats;
  final int? maxSeats;
  final BillingCycle billingCycle;
}

final class UsageBasedPricing extends PricingModel {
  const UsageBasedPricing({
    required super.currency,
    required this.baseAmountCents,
    required this.usageUnit,
    required this.ratePerUnitCents,
    required this.includedUnits,
    this.billingCycle = BillingCycle.monthly,
  });

  final int baseAmountCents;
  final String usageUnit;
  final int ratePerUnitCents;
  final int includedUnits;
  final BillingCycle billingCycle;
}

enum BillingCycle { monthly, quarterly, annually }

/// Plan limits — usage caps enforced by the entitlement engine.
class PlanLimits {
  const PlanLimits({
    this.maxStorageBytes,
    this.maxApiCallsPerDay,
    this.maxUsers,
    this.maxBranches,
    this.maxForms,
    this.maxSubmissionsPerMonth,
    this.customLimits = const {},
  });

  final int? maxStorageBytes;
  final int? maxApiCallsPerDay;
  final int? maxUsers;
  final int? maxBranches;
  final int? maxForms;
  final int? maxSubmissionsPerMonth;
  final Map<String, int> customLimits;

  int? getLimit(String key) {
    return switch (key) {
      'maxStorageBytes' => maxStorageBytes,
      'maxApiCallsPerDay' => maxApiCallsPerDay,
      'maxUsers' => maxUsers,
      'maxBranches' => maxBranches,
      'maxForms' => maxForms,
      'maxSubmissionsPerMonth' => maxSubmissionsPerMonth,
      _ => customLimits[key],
    };
  }
}
