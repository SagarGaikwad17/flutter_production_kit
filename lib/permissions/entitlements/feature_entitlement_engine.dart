import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/domain/entities/feature_entitlement.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Engine for evaluating feature entitlements (subscription-based access).
///
/// Design rationale:
/// - Entitlements are a SEPARATE layer from role permissions.
/// - A user may have role-based permission but lack the subscription tier.
/// - Entitlements can be time-limited (trials, promos).
/// - Entitlements can be branch-scoped (enterprise plan for specific branches).
///
/// Evaluation order:
/// 1. Check if entitlement is active (not expired, not disabled).
/// 2. Check if user's tier meets the required tier.
/// 3. Check branch scope if applicable.
/// 4. Return typed denial if any check fails.
class FeatureEntitlementEngine {
  FeatureEntitlementEngine({
    this.trialGracePeriod = const Duration(hours: 24),
  });

  static const String _tag = 'FeatureEntitlementEngine';

  /// Grace period after trial expiry — allows soft downgrade.
  final Duration trialGracePeriod;

  Map<String, FeatureEntitlement> _entitlements = {};
  SubscriptionTier _userTier = SubscriptionTier.free;

  /// Set the user's entitlements — called after backend sync.
  void setEntitlements(Map<String, FeatureEntitlement> entitlements) {
    _entitlements = entitlements;
    AppLogger.info(
      _tag,
      'Entitlements updated: ${_entitlements.length} features for tier: ${_userTier.name}',
    );
  }

  /// Set the user's current subscription tier.
  void setUserTier(SubscriptionTier tier) {
    _userTier = tier;
    AppLogger.info(_tag, 'User tier updated: ${tier.name}');
  }

  /// Check if a feature is accessible.
  AuthorizationResult? check({
    required String featureId,
    String? branchId,
  }) {
    final entitlement = _entitlements[featureId];

    if (entitlement == null) {
      return AuthorizationDeniedEntitlementMissing(
        reason: 'No entitlement for feature "$featureId".',
        requiredFeature: featureId,
        currentTier: _userTier.name,
      );
    }

    if (!entitlement.isActive) {
      if (entitlement.isExpired) {
        // Check if in grace period (for trials).
        final inGrace = _isInGracePeriod(entitlement);
        if (inGrace) {
          return AuthorizationAllowed(
            reason: 'Feature accessible during trial grace period.',
            viaEntitlement: featureId,
          );
        }

        return AuthorizationDeniedEntitlementMissing(
          reason: 'Entitlement for "$featureId" has expired.',
          requiredFeature: featureId,
          requiredTier: entitlement.tier.name,
          currentTier: _userTier.name,
        );
      }

      return AuthorizationDeniedEntitlementMissing(
        reason: 'Entitlement for "$featureId" is disabled.',
        requiredFeature: featureId,
      );
    }

    if (!_userTier.canAccess(entitlement.tier)) {
      return AuthorizationDeniedEntitlementMissing(
        reason: 'Current tier "${_userTier.name}" does not meet '
            'required tier "${entitlement.tier.name}" for "$featureId".',
        requiredFeature: featureId,
        requiredTier: entitlement.tier.name,
        currentTier: _userTier.name,
      );
    }

    if (!entitlement.appliesToBranch(branchId)) {
      return AuthorizationDeniedBranchMismatch(
        reason: 'Entitlement for "$featureId" does not apply to '
            'branch "${branchId ?? "unknown"}".',
        userBranchId: branchId,
        resourceBranchId: branchId,
      );
    }

    return null;
  }

  /// Get all active entitlements.
  List<FeatureEntitlement> get activeEntitlements =>
      _entitlements.values.where((e) => e.isActive).toList();

  /// Get entitlements expiring soon (within 7 days).
  List<FeatureEntitlement> get expiringSoon {
    final now = DateTime.now();
    final threshold = now.add(const Duration(days: 7));
    return _entitlements.values
        .where((e) =>
            e.isActive &&
            e.expiresAt != null &&
            e.expiresAt!.isBefore(threshold))
        .toList();
  }

  /// Check if an expired trial entitlement is still in the grace period.
  bool _isInGracePeriod(FeatureEntitlement entitlement) {
    if (entitlement.tier != SubscriptionTier.free) return false;
    if (entitlement.expiresAt == null) return false;

    final now = DateTime.now();
    return now.difference(entitlement.expiresAt!) < trialGracePeriod;
  }
}
