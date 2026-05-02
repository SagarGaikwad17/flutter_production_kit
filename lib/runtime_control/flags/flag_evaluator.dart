import 'dart:math';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/feature_flag.dart';
import 'package:flutter_production_kit/runtime_control/domain/entities/feature_evaluation_result.dart';

/// Flag evaluator — evaluates a single feature flag against a user context.
///
/// Design rationale:
/// - Pure evaluation logic — no side effects, no storage, no network.
/// - Takes a FeatureFlag + user context → returns FeatureEvaluationResult.
/// - Evaluation follows the flag's evaluationOrder:
///   1. Check kill switch (always first, cannot be overridden).
///   2. Check expiration.
///   3. Check app version compatibility.
///   4. Check tenant restrictions.
///   5. Check branch restrictions.
///   6. Check white-label restrictions.
///   7. Check targeting rules (first match wins).
///   8. Check rollout percentage.
///   9. Check base enabled state.
///
/// Deterministic: same inputs always produce the same result.
class FlagEvaluator {
  const FlagEvaluator();

  static const String _tag = 'FlagEvaluator';

  /// Evaluate a feature flag against a user context.
  FeatureEvaluationResult evaluate({
    required FeatureFlag flag,
    String? userId,
    String? tenantId,
    String? branchId,
    String? whiteLabelClient,
    String? region,
    List<String>? roles,
    Set<String>? entitlements,
    String? appVersion,
    bool killSwitchActive = false,
    String? killSwitchReason,
  }) {
    // Step 1: Kill switch — always first, cannot be overridden.
    if (killSwitchActive) {
      AppLogger.warning(
        _tag,
        'Feature "${flag.key}" blocked by kill switch: $killSwitchReason',
      );
      return FeatureDisabledKillSwitch(
        featureKey: flag.key,
        killSwitchKey: flag.killSwitchKey ?? flag.key,
        reason: killSwitchReason,
      );
    }

    // Step 2: Expiration check.
    if (flag.isExpired) {
      AppLogger.info(_tag, 'Feature "${flag.key}" has expired.');
      return FeatureDisabledExpired(
        featureKey: flag.key,
        expiredAt: flag.expiresAt!,
        reason: 'Feature flag expired at ${flag.expiresAt}',
      );
    }

    // Step 3: App version compatibility.
    final versionResult = _checkAppVersion(flag, appVersion);
    if (versionResult != null) return versionResult;

    // Step 4: Tenant restrictions.
    final tenantResult = _checkTenantRestriction(flag, tenantId);
    if (tenantResult != null) return tenantResult;

    // Step 5: Branch restrictions.
    final branchResult = _checkBranchRestriction(flag, branchId);
    if (branchResult != null) return branchResult;

    // Step 6: White-label restrictions.
    final whiteLabelResult = _checkWhiteLabelRestriction(flag, whiteLabelClient);
    if (whiteLabelResult != null) return whiteLabelResult;

    // Step 7: Region restrictions.
    final regionResult = _checkRegionRestriction(flag, region);
    if (regionResult != null) return regionResult;

    // Step 8: Targeting rules (first match wins).
    if (flag.hasTargeting) {
      final targetingResult = _checkTargetingRules(
        flag,
        userId: userId,
        tenantId: tenantId,
        branchId: branchId,
        roles: roles,
      );
      if (targetingResult != null) return targetingResult;
    }

    // Step 9: Entitlement check.
    if (flag.requiredEntitlements.isNotEmpty) {
      final entitlementResult = _checkEntitlements(
        flag,
        entitlements: entitlements,
      );
      if (entitlementResult != null) return entitlementResult;
    }

    // Step 10: Rollout percentage.
    final rolloutResult = _checkRollout(
      flag,
      userId: userId,
    );
    if (rolloutResult != null) return rolloutResult;

    // Step 11: Base enabled state.
    if (!flag.enabled) {
      return FeatureDisabled(
        featureKey: flag.key,
        reason: 'Feature flag is disabled.',
      );
    }

    return FeatureEnabled(
      featureKey: flag.key,
      reason: 'Feature flag enabled for user.',
    );
  }

  FeatureEvaluationResult? _checkAppVersion(FeatureFlag flag, String? appVersion) {
    if (appVersion == null) return null;

    final minVersion = flag.minAppVersion;
    if (minVersion != null && _compareVersions(appVersion, minVersion) < 0) {
      return FeatureDisabledAppVersion(
        featureKey: flag.key,
        minVersion: minVersion,
        currentVersion: appVersion,
        reason: 'App version $appVersion is below minimum $minVersion.',
      );
    }

    final maxVersion = flag.maxAppVersion;
    if (maxVersion != null && _compareVersions(appVersion, maxVersion) > 0) {
      return FeatureDisabledAppVersion(
        featureKey: flag.key,
        maxVersion: maxVersion,
        currentVersion: appVersion,
        reason: 'App version $appVersion exceeds maximum $maxVersion.',
      );
    }

    return null;
  }

  FeatureEvaluationResult? _checkTenantRestriction(FeatureFlag flag, String? tenantId) {
    if (tenantId == null) return null;

    final blocked = flag.blockedTenants;
    if (blocked != null && blocked.contains(tenantId)) {
      return FeatureDisabledTenantRestricted(
        featureKey: flag.key,
        tenantId: tenantId,
        reason: 'Feature disabled for tenant $tenantId.',
      );
    }

    final allowed = flag.allowedTenants;
    if (allowed != null && allowed.isNotEmpty && !allowed.contains(tenantId)) {
      return FeatureDisabledTenantRestricted(
        featureKey: flag.key,
        tenantId: tenantId,
        reason: 'Feature not enabled for tenant $tenantId.',
      );
    }

    return null;
  }

  FeatureEvaluationResult? _checkBranchRestriction(FeatureFlag flag, String? branchId) {
    if (branchId == null) return null;

    final blocked = flag.blockedBranches;
    if (blocked != null && blocked.contains(branchId)) {
      return FeatureDisabledBranchRestricted(
        featureKey: flag.key,
        branchId: branchId,
        reason: 'Feature disabled for branch $branchId.',
      );
    }

    final allowed = flag.allowedBranches;
    if (allowed != null && allowed.isNotEmpty && !allowed.contains(branchId)) {
      return FeatureDisabledBranchRestricted(
        featureKey: flag.key,
        branchId: branchId,
        reason: 'Feature not enabled for branch $branchId.',
      );
    }

    return null;
  }

  FeatureEvaluationResult? _checkWhiteLabelRestriction(
    FeatureFlag flag,
    String? whiteLabelClient,
  ) {
    if (whiteLabelClient == null) return null;

    final blocked = flag.blockedWhiteLabels;
    if (blocked != null && blocked.contains(whiteLabelClient)) {
      return FeatureDisabledWhiteLabelRestricted(
        featureKey: flag.key,
        whiteLabelClient: whiteLabelClient,
        reason: 'Feature disabled for client $whiteLabelClient.',
      );
    }

    final allowed = flag.allowedWhiteLabels;
    if (allowed != null && allowed.isNotEmpty && !allowed.contains(whiteLabelClient)) {
      return FeatureDisabledWhiteLabelRestricted(
        featureKey: flag.key,
        whiteLabelClient: whiteLabelClient,
        reason: 'Feature not enabled for client $whiteLabelClient.',
      );
    }

    return null;
  }

  FeatureEvaluationResult? _checkRegionRestriction(FeatureFlag flag, String? region) {
    if (region == null) return null;

    final blocked = flag.blockedRegions;
    if (blocked != null && blocked.contains(region)) {
      return FeatureDisabled(
        featureKey: flag.key,
        reason: 'Feature disabled for region $region.',
      );
    }

    final allowed = flag.allowedRegions;
    if (allowed != null && allowed.isNotEmpty && !allowed.contains(region)) {
      return FeatureDisabled(
        featureKey: flag.key,
        reason: 'Feature not enabled for region $region.',
      );
    }

    return null;
  }

  FeatureEvaluationResult? _checkTargetingRules(
    FeatureFlag flag, {
    String? userId,
    String? tenantId,
    String? branchId,
    List<String>? roles,
  }) {
    final sortedRules = List<TargetingRule>.from(flag.targetingRules)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sortedRules) {
      final matches = _ruleMatches(
        rule,
        userId: userId,
        tenantId: tenantId,
        branchId: branchId,
        roles: roles,
      );

      if (matches) {
        AppLogger.debug(
          _tag,
          'Feature "${flag.key}" targeting rule matched: ${rule.id}',
        );
        return FeatureEnabled(
          featureKey: flag.key,
          reason: 'Matched targeting rule: ${rule.description ?? rule.id}',
          viaTargetingRule: rule.id,
        );
      }
    }

    // No targeting rule matched — flag is disabled for this user.
    if (flag.enabled && !flag.hasTargeting) {
      return null; // Fall through to base enabled state.
    }

    return FeatureDisabled(
      featureKey: flag.key,
      reason: 'No targeting rule matched for this user.',
    );
  }

  bool _ruleMatches(
    TargetingRule rule, {
    String? userId,
    String? tenantId,
    String? branchId,
    List<String>? roles,
  }) {
    return switch (rule.condition) {
      UserIdsCondition(:final userIds) =>
        userId != null && userIds.contains(userId),
      RolesCondition(roles: final targetRoles) =>
        roles != null && targetRoles.any(roles.contains),
      TenantIdsCondition(:final tenantIds) =>
        tenantId != null && tenantIds.contains(tenantId),
      BranchIdsCondition(:final branchIds) =>
        branchId != null && branchIds.contains(branchId),
      SegmentsCondition() => true,
      PercentageCondition(:final percentage, :final salt) =>
        _isInPercentage(userId ?? '', percentage, salt),
      CustomCondition() => true,
    };
  }

  FeatureEvaluationResult? _checkEntitlements(
    FeatureFlag flag, {
    Set<String>? entitlements,
  }) {
    if (flag.requiredEntitlements.isEmpty) return null;
    if (entitlements == null) {
      return FeatureDisabledEntitlement(
        featureKey: flag.key,
        requiredEntitlements: flag.requiredEntitlements,
        reason: 'No entitlements available for check.',
      );
    }

    for (final required in flag.requiredEntitlements) {
      if (!entitlements.contains(required)) {
        return FeatureDisabledEntitlement(
          featureKey: flag.key,
          requiredEntitlements: flag.requiredEntitlements,
          reason: 'Missing required entitlement: $required',
        );
      }
    }

    return null;
  }

  FeatureEvaluationResult? _checkRollout(FeatureFlag flag, {String? userId}) {
    if (flag.rolloutPercentage >= 100) return null;
    if (flag.rolloutPercentage <= 0) {
      return FeatureDisabledRollout(
        featureKey: flag.key,
        rolloutPercentage: 0,
        reason: 'Rollout is 0% — feature disabled for everyone.',
      );
    }

    if (userId == null) {
      return FeatureDisabledRollout(
        featureKey: flag.key,
        rolloutPercentage: flag.rolloutPercentage,
        reason: 'User ID required for rollout assignment.',
      );
    }

    final isInRollout = _isInPercentage(
      userId,
      flag.rolloutPercentage,
      flag.rolloutSalt,
    );

    if (!isInRollout) {
      return FeatureDisabledRollout(
        featureKey: flag.key,
        rolloutPercentage: flag.rolloutPercentage,
        reason: 'User not in ${flag.rolloutPercentage}% rollout group.',
      );
    }

    return null;
  }

  bool _isInPercentage(String userId, int percentage, String salt) {
    final input = '$userId:$salt:$percentage';
    final hash = _hashString(input);
    final bucket = hash % 100;
    return bucket < percentage;
  }

  int _hashString(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.abs();
  }

  int _compareVersions(String versionA, String versionB) {
    final partsA = versionA.split('.').map(int.tryParse).toList();
    final partsB = versionB.split('.').map(int.tryParse).toList();

    final maxLen = max(partsA.length, partsB.length);
    for (var i = 0; i < maxLen; i++) {
      final a = i < partsA.length ? (partsA[i] ?? 0) : 0;
      final b = i < partsB.length ? (partsB[i] ?? 0) : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }
}
