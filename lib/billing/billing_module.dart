import 'package:flutter_production_kit/billing/audits/billing_audit_manager.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/billing/entitlements/entitlement_engine.dart';
import 'package:flutter_production_kit/billing/entitlements/feature_mapping_engine.dart';
import 'package:flutter_production_kit/billing/grace_periods/grace_period_manager.dart';
import 'package:flutter_production_kit/billing/invoices/billing_event_processor.dart';
import 'package:flutter_production_kit/billing/invoices/invoice_manager.dart';
import 'package:flutter_production_kit/billing/plans/plan_manager.dart';
import 'package:flutter_production_kit/billing/plans/plan_transition_manager.dart';
import 'package:flutter_production_kit/billing/policies/access_policy.dart';
import 'package:flutter_production_kit/billing/policies/downgrade_policy.dart';
import 'package:flutter_production_kit/billing/policies/grace_policy.dart';
import 'package:flutter_production_kit/billing/recovery/payment_recovery_engine.dart';
import 'package:flutter_production_kit/billing/subscriptions/subscription_engine.dart';
import 'package:flutter_production_kit/billing/subscriptions/subscription_state_machine.dart';
import 'package:flutter_production_kit/billing/tracing/billing_observer.dart';
import 'package:flutter_production_kit/billing/tracing/billing_trace.dart';
import 'package:flutter_production_kit/billing/transitions/downgrade_manager.dart';
import 'package:flutter_production_kit/billing/transitions/upgrade_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';

/// Billing module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All billing dependencies are registered here in one place.
/// - The SubscriptionEngine is the central orchestrator for subscription lifecycle.
/// - The EntitlementEngine is the central access decision point.
/// - The BillingEventProcessor handles idempotent webhook processing.
/// - Policies are configurable — swap for different business rules.
///
/// Usage:
/// ```dart
/// BillingModule.register(getIt,
///   subscriptionRepository: mySubRepo,
///   planRepository: myPlanRepo,
///   invoiceRepository: myInvoiceRepo,
///   billingEventRepository: myEventRepo,
///   auditRepository: myAuditRepo,
/// );
///
/// // Later in code:
/// final subscriptionEngine = getIt<SubscriptionEngine>();
/// final entitlementEngine = getIt<EntitlementEngine>();
/// ```
abstract final class BillingModule {
  BillingModule._();

  static const String _tag = 'BillingModule';

  static void register(
    GetIt getIt, {
    required SubscriptionRepository subscriptionRepository,
    required PlanRepository planRepository,
    required InvoiceRepository invoiceRepository,
    required BillingEventRepository billingEventRepository,
    required BillingAuditRepository auditRepository,
    GracePolicy? gracePolicy,
    DowngradePolicy? downgradePolicy,
    AccessPolicy? accessPolicy,
    Duration paymentPendingTimeout = const Duration(hours: 24),
    int maxPaymentRetries = 4,
    List<String>? defaultRestrictedActions,
    Map<String, FeatureMapping>? initialFeatureMappings,
    Set<String>? initiallyKilledFeatures,
  }) {
    AppLogger.info(_tag, 'Registering billing module...');

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<GracePolicy>(
      () => gracePolicy ?? const GracePolicy(),
    );

    getIt.registerLazySingleton<DowngradePolicy>(
      () => downgradePolicy ?? const DowngradePolicy(),
    );

    getIt.registerLazySingleton<AccessPolicy>(
      () => accessPolicy ?? const AccessPolicy(),
    );

    // ── Feature Mapping ──────────────────────────────────────────────────────

    getIt.registerLazySingleton<FeatureMappingEngine>(
      () => FeatureMappingEngine(
        initialMappings: initialFeatureMappings,
        killedFeatures: initiallyKilledFeatures,
      ),
    );

    // ── State Machine ────────────────────────────────────────────────────────

    getIt.registerLazySingleton<SubscriptionStateMachine>(
      () => const SubscriptionStateMachine(),
    );

    // ── Plan Management ──────────────────────────────────────────────────────

    getIt.registerLazySingleton<PlanManager>(
      () => PlanManager(planRepository: planRepository),
    );

    getIt.registerLazySingleton<PlanTransitionManager>(
      () => PlanTransitionManager(planManager: getIt<PlanManager>()),
    );

    // ── Subscription Engine ──────────────────────────────────────────────────

    getIt.registerLazySingleton<SubscriptionEngine>(
      () => SubscriptionEngine(
        subscriptionRepository: subscriptionRepository,
        auditRepository: auditRepository,
        stateMachine: getIt<SubscriptionStateMachine>(),
      ),
    );

    // ── Grace Period ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<GracePeriodManager>(
      () => const GracePeriodManager(),
    );

    // ── Payment Recovery ─────────────────────────────────────────────────────

    getIt.registerLazySingleton<PaymentRecoveryEngine>(
      () => PaymentRecoveryEngine(
        subscriptionRepository: subscriptionRepository,
        eventRepository: billingEventRepository,
        maxRetries: maxPaymentRetries,
      ),
    );

    // ── Transitions ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<UpgradeManager>(
      () => UpgradeManager(
        transitionManager: getIt<PlanTransitionManager>(),
        subscriptionRepository: subscriptionRepository,
        eventRepository: billingEventRepository,
      ),
    );

    getIt.registerLazySingleton<DowngradeManager>(
      () => DowngradeManager(
        transitionManager: getIt<PlanTransitionManager>(),
        subscriptionRepository: subscriptionRepository,
        eventRepository: billingEventRepository,
        downgradePolicy: getIt<DowngradePolicy>(),
      ),
    );

    // ── Entitlement Engine ───────────────────────────────────────────────────

    getIt.registerLazySingleton<EntitlementEngine>(
      () => EntitlementEngine(
        subscriptionRepository: subscriptionRepository,
        planRepository: planRepository,
        featureMappingEngine: getIt<FeatureMappingEngine>(),
      ),
    );

    // ── Invoices ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<InvoiceManager>(
      () => InvoiceManager(invoiceRepository: invoiceRepository),
    );

    getIt.registerLazySingleton<BillingEventProcessor>(
      () => BillingEventProcessor(eventRepository: billingEventRepository),
    );

    // ── Audit ────────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<BillingAuditManager>(
      () => BillingAuditManager(auditRepository: auditRepository),
    );

    // ── Tracing ──────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<BillingTrace>(
      () => BillingTrace(),
    );

    getIt.registerLazySingleton<BillingObserver>(
      () => const LoggingBillingObserver(),
    );

    AppLogger.info(_tag, 'Billing module registration complete.');
  }

  /// Unregister all billing dependencies.
  static void unregister(GetIt getIt) {
    getIt.unregister<SubscriptionEngine>();
    getIt.unregister<SubscriptionStateMachine>();
    getIt.unregister<PlanManager>();
    getIt.unregister<PlanTransitionManager>();
    getIt.unregister<EntitlementEngine>();
    getIt.unregister<FeatureMappingEngine>();
    getIt.unregister<GracePeriodManager>();
    getIt.unregister<PaymentRecoveryEngine>();
    getIt.unregister<UpgradeManager>();
    getIt.unregister<DowngradeManager>();
    getIt.unregister<InvoiceManager>();
    getIt.unregister<BillingEventProcessor>();
    getIt.unregister<BillingAuditManager>();
    getIt.unregister<BillingTrace>();
    getIt.unregister<BillingObserver>();
    getIt.unregister<GracePolicy>();
    getIt.unregister<DowngradePolicy>();
    getIt.unregister<AccessPolicy>();

    AppLogger.info(_tag, 'Billing module unregistered.');
  }
}
