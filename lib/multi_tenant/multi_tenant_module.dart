import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/multi_tenant/audits/tenant_audit_engine.dart';
import 'package:flutter_production_kit/multi_tenant/branches/branch_scope_engine.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';
import 'package:flutter_production_kit/multi_tenant/entitlements/tenant_entitlement_engine.dart';
import 'package:flutter_production_kit/multi_tenant/isolation/cross_tenant_protection_engine.dart';
import 'package:flutter_production_kit/multi_tenant/isolation/tenant_guard.dart';
import 'package:flutter_production_kit/multi_tenant/onboarding/tenant_onboarding_engine.dart';
import 'package:flutter_production_kit/multi_tenant/policies/tenant_policy_manager.dart';
import 'package:flutter_production_kit/multi_tenant/resolution/runtime_tenant_resolver.dart';
import 'package:flutter_production_kit/multi_tenant/tenants/tenant_context_manager.dart';
import 'package:flutter_production_kit/multi_tenant/tenants/tenant_engine.dart';
import 'package:flutter_production_kit/multi_tenant/tracing/tenant_trace_engine.dart';
import 'package:flutter_production_kit/multi_tenant/white_label/branding_engine.dart';
import 'package:flutter_production_kit/multi_tenant/white_label/theme_runtime_manager.dart';
import 'package:get_it/get_it.dart';

/// Multi-tenant module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All multi-tenant dependencies are registered here in one place.
/// - Repository interfaces are injected — concrete implementations depend on storage backend.
/// - TenantGuard and CrossTenantProtectionEngine enforce isolation at every layer.
/// - BrandingEngine resolves white-label themes per tenant.
/// - TenantOnboardingEngine orchestrates enterprise tenant provisioning.
///
/// Usage:
/// ```dart
/// MultiTenantModule.register(getIt,
///   tenantRepository: myTenantRepo,
///   branchRepository: myBranchRepo,
///   brandingRepository: myBrandingRepo,
///   sessionRepository: mySessionRepo,
///   compliancePolicyRepository: myComplianceRepo,
/// );
///
/// // Later in code:
/// final tenantEngine = getIt<TenantEngine>();
/// final tenantContextManager = getIt<TenantContextManager>();
/// final tenantGuard = getIt<TenantGuard>();
/// final brandingEngine = getIt<BrandingEngine>();
/// ```
abstract final class MultiTenantModule {
  MultiTenantModule._();

  static const String _tag = 'MultiTenantModule';

  static void register(
    GetIt getIt, {
    required ITenantRepository tenantRepository,
    required IBranchRepository branchRepository,
    required IBrandingRepository brandingRepository,
    required ITenantSessionRepository sessionRepository,
    required ICompliancePolicyRepository compliancePolicyRepository,
    List<String>? escalationRoles,
  }) {
    AppLogger.info(_tag, 'Registering multi-tenant module...');

    // ── Core Engines ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantEngine>(
      () => TenantEngine(tenantRepository: tenantRepository),
    );

    getIt.registerLazySingleton<TenantContextManager>(
      () => TenantContextManager(
        tenantRepository: tenantRepository,
        sessionRepository: sessionRepository,
      ),
    );

    // ── Branch Scope ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<BranchScopeEngine>(
      () => BranchScopeEngine(
        branchRepository: branchRepository,
        escalationRoles: escalationRoles ?? const ['super_admin', 'tenant_admin'],
      ),
    );

    // ── White-Label Branding ─────────────────────────────────────────────────

    getIt.registerLazySingleton<BrandingEngine>(
      () => BrandingEngine(
        brandingRepository: brandingRepository,
      ),
    );

    getIt.registerLazySingleton<ThemeRuntimeManager>(
      () => ThemeRuntimeManager(
        brandingEngine: getIt<BrandingEngine>(),
      ),
    );

    // ── Isolation ────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantGuard>(
      () => const TenantGuard(),
    );

    getIt.registerLazySingleton<CrossTenantProtectionEngine>(
      () => const CrossTenantProtectionEngine(),
    );

    // ── Resolution ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<RuntimeTenantResolver>(
      () => RuntimeTenantResolver(
        tenantRepository: tenantRepository,
        sessionRepository: sessionRepository,
      ),
    );

    // ── Onboarding ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantOnboardingEngine>(
      () => TenantOnboardingEngine(
        tenantRepository: tenantRepository,
        brandingRepository: brandingRepository,
        compliancePolicyRepository: compliancePolicyRepository,
      ),
    );

    // ── Entitlements ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantEntitlementEngine>(
      () => const TenantEntitlementEngine(),
    );

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantPolicyManager>(
      () => TenantPolicyManager(
        policyRepository: compliancePolicyRepository,
      ),
    );

    // ── Audits ───────────────────────────────────────────────────────────────

    getIt.registerFactory<TenantAuditEngine>(
      () => TenantAuditEngine(
        onAuditEvent: (event) {
          AppLogger.info(
            _tag,
            'Tenant audit: ${event.eventType} (tenant: ${event.tenantId})',
          );
        },
      ),
    );

    // ── Tracing ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<TenantTraceEngine>(
      () => const TenantTraceEngine(),
    );

    AppLogger.info(_tag, 'Multi-tenant module registration complete.');
  }

  /// Unregister all multi-tenant dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<TenantEngine>();
    getIt.unregister<TenantContextManager>();
    getIt.unregister<BranchScopeEngine>();
    getIt.unregister<BrandingEngine>();
    getIt.unregister<ThemeRuntimeManager>();
    getIt.unregister<TenantGuard>();
    getIt.unregister<CrossTenantProtectionEngine>();
    getIt.unregister<RuntimeTenantResolver>();
    getIt.unregister<TenantOnboardingEngine>();
    getIt.unregister<TenantEntitlementEngine>();
    getIt.unregister<TenantPolicyManager>();
    getIt.unregister<TenantAuditEngine>();
    getIt.unregister<TenantTraceEngine>();

    AppLogger.info(_tag, 'Multi-tenant module unregistered.');
  }
}
