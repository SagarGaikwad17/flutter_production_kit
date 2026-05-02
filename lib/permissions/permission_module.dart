import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';
import 'package:flutter_production_kit/permissions/engine/policy_evaluator.dart';
import 'package:flutter_production_kit/permissions/engine/role_resolver.dart';
import 'package:flutter_production_kit/permissions/entitlements/feature_entitlement_engine.dart';
import 'package:flutter_production_kit/permissions/policies/allow_override_policy.dart';
import 'package:flutter_production_kit/permissions/policies/deny_override_policy.dart';
import 'package:flutter_production_kit/permissions/policies/temporary_access_policy.dart';
import 'package:get_it/get_it.dart';

/// Permission module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All permission dependencies are registered here in one place.
/// - The engine is a singleton — single evaluation point for all checks.
/// - Guards are factories — created per-user/context for isolation.
/// - Policies can be swapped (deny-overrides is the safe default).
///
/// Usage:
/// ```dart
/// PermissionModule.register(getIt);
///
/// // Later in code:
/// final engine = getIt<PermissionEngine>();
/// final result = engine.check(
///   userId: 'user_123',
///   action: 'delete',
///   resource: 'patient',
/// );
/// ```
abstract final class PermissionModule {
  PermissionModule._();

  static const String _tag = 'PermissionModule';

  static void register(
    GetIt getIt, {
    AuthorizationPolicy? defaultPolicy,
    TemporaryAccessPolicy? temporaryAccessPolicy,
    Duration stalePermissionTimeout = const Duration(hours: 4),
    List<String> offlineBlockActions = const [
      'delete',
      'admin',
      'export',
      'transfer',
    ],
  }) {
    AppLogger.info(_tag, 'Registering permission module...');

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuthorizationPolicy>(
      () => defaultPolicy ?? const DenyOverridesPolicy(),
      instanceName: 'defaultPolicy',
    );

    getIt.registerFactory<DenyOverridesPolicy>(
      () => const DenyOverridesPolicy(),
    );

    getIt.registerFactory<AllowOverridesPolicy>(
      () => const AllowOverridesPolicy(),
    );

    getIt.registerLazySingleton<TemporaryAccessPolicy>(
      () => temporaryAccessPolicy ?? const TemporaryAccessPolicy(),
    );

    // ── Engine Core ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RoleResolver>(
      () => RoleResolver(
        temporaryAccessPolicy: getIt<TemporaryAccessPolicy>(),
      ),
    );

    getIt.registerLazySingleton<PolicyEvaluator>(
      () => PolicyEvaluator(
        defaultPolicy: getIt<AuthorizationPolicy>(instanceName: 'defaultPolicy'),
      ),
    );

    getIt.registerLazySingleton<FeatureEntitlementEngine>(
      () => FeatureEntitlementEngine(),
    );

    getIt.registerLazySingleton<PermissionEngine>(
      () => PermissionEngine(
        roleResolver: getIt<RoleResolver>(),
        policyEvaluator: getIt<PolicyEvaluator>(),
        offlineBlockActions: offlineBlockActions,
        stalePermissionTimeout: stalePermissionTimeout,
      ),
    );

    // ── Sync Manager ─────────────────────────────────────────────────────────

    // PermissionSyncManager requires a fetch callback — register as lazy singleton
    // since it will be configured once with the backend-specific implementation.
    // Users should call getIt<PermissionSyncManager>() after registering with
    // a custom fetch callback.

    // ── Guards ───────────────────────────────────────────────────────────────

    // Guards are created per-user/context — use factory pattern with direct instantiation.
    // Users should create guards manually with the engine from DI:
    //   final engine = getIt<PermissionEngine>();
    //   final guard = RoutePermissionGuard(
    //     permissionEngine: engine,
    //     userId: userId,
    //   );

    AppLogger.info(_tag, 'Permission module registration complete.');
  }

  /// Unregister all permission dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<PermissionEngine>();
    getIt.unregister<FeatureEntitlementEngine>();
    getIt.unregister<PolicyEvaluator>();
    getIt.unregister<RoleResolver>();
    getIt.unregister<TemporaryAccessPolicy>();
    getIt.unregister<AllowOverridesPolicy>();
    getIt.unregister<DenyOverridesPolicy>();
    getIt.unregister<AuthorizationPolicy>(instanceName: 'defaultPolicy');

    AppLogger.info(_tag, 'Permission module unregistered.');
  }
}
