import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/permissions/domain/entities/access_context.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/domain/entities/permission.dart';
import 'package:flutter_production_kit/permissions/policies/deny_override_policy.dart';
import 'package:flutter_production_kit/permissions/policies/allow_override_policy.dart';

/// Evaluates authorization policies — determines how multi-role conflicts are resolved.
///
/// Design rationale:
/// - The default policy is [DenyOverridesPolicy] — security-first.
///   If ANY role denies access, access is denied regardless of other roles.
/// - [AllowOverridesPolicy] can be used for less security-sensitive contexts.
/// - The evaluator coordinates between policies and produces the final result.
/// - Policy selection is explicit — not implicit or random.
class PolicyEvaluator {
  PolicyEvaluator({
    AuthorizationPolicy? defaultPolicy,
  }) : _defaultPolicy = defaultPolicy ?? const DenyOverridesPolicy();

  static const String _tag = 'PolicyEvaluator';

  final AuthorizationPolicy _defaultPolicy;
  final Map<String, AuthorizationPolicy> _resourcePolicies = {};

  /// Register a policy for a specific resource type.
  void registerPolicy(String resource, AuthorizationPolicy policy) {
    _resourcePolicies[resource] = policy;
    AppLogger.info(_tag, 'Policy registered for resource "$resource": ${policy.name}');
  }

  /// Evaluate authorization using the appropriate policy.
  AuthorizationResult evaluate({
    required AccessContext context,
    required Set<Permission> userPermissions,
    required List<String> userRoles,
    List<String>? denyingRoles,
    List<String>? allowingRoles,
  }) {
    final policy = _resourcePolicies[context.resource] ?? _defaultPolicy;

    AppLogger.debug(
      _tag,
      'Evaluating ${context.action}:${context.resource} '
      'using policy: ${policy.name}',
    );

    return policy.evaluate(
      context: context,
      userPermissions: userPermissions,
      userRoles: userRoles,
      denyingRoles: denyingRoles ?? [],
      allowingRoles: allowingRoles ?? [],
    );
  }
}

/// Abstract authorization policy — defines how conflicts are resolved.
abstract class AuthorizationPolicy {
  const AuthorizationPolicy();

  /// Human-readable policy name.
  String get name;

  /// Evaluate authorization and return a typed result.
  AuthorizationResult evaluate({
    required AccessContext context,
    required Set<Permission> userPermissions,
    required List<String> userRoles,
    required List<String> denyingRoles,
    required List<String> allowingRoles,
  });
}
