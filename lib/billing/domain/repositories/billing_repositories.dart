import 'package:flutter_production_kit/billing/domain/entities/billing_audit_entry.dart';
import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/billing/domain/entities/invoice_state.dart';
import 'package:flutter_production_kit/billing/domain/entities/plan_config.dart';
import 'package:flutter_production_kit/billing/domain/entities/subscription_state.dart';

/// Abstract repository for subscriptions.
abstract class SubscriptionRepository {
  const SubscriptionRepository();

  /// Get a subscription by ID.
  Future<SubscriptionState?> getSubscription(String subscriptionId);

  /// Get subscriptions for a user.
  Future<List<SubscriptionState>> getSubscriptionsForUser(String userId);

  /// Get subscriptions for a tenant.
  Future<List<SubscriptionState>> getSubscriptionsForTenant(String tenantId);

  /// Save a subscription state.
  Future<void> saveSubscription(SubscriptionState subscription);

  /// Update a subscription state.
  Future<void> updateSubscription(SubscriptionState subscription);

  /// Delete a subscription.
  Future<void> deleteSubscription(String subscriptionId);
}

/// Abstract repository for billing events.
abstract class BillingEventRepository {
  const BillingEventRepository();

  /// Save a billing event.
  Future<void> saveEvent(BillingEvent event);

  /// Get an event by idempotency key.
  Future<BillingEvent?> getEventByIdempotencyKey(String idempotencyKey);

  /// Get events for a subscription.
  Future<List<BillingEvent>> getEventsForSubscription(String subscriptionId);

  /// Get unprocessed events.
  Future<List<BillingEvent>> getUnprocessedEvents();

  /// Mark an event as processed.
  Future<void> markEventProcessed(String eventId, DateTime processedAt);
}

/// Abstract repository for invoices.
abstract class InvoiceRepository {
  const InvoiceRepository();

  /// Save an invoice.
  Future<void> saveInvoice(InvoiceState invoice);

  /// Get an invoice by ID.
  Future<InvoiceState?> getInvoice(String invoiceId);

  /// Get invoices for a subscription.
  Future<List<InvoiceState>> getInvoicesForSubscription(String subscriptionId);

  /// Get invoices for a user.
  Future<List<InvoiceState>> getInvoicesForUser(String userId);

  /// Get an invoice by idempotency key.
  Future<InvoiceState?> getInvoiceByIdempotencyKey(String idempotencyKey);

  /// Update an invoice.
  Future<void> updateInvoice(InvoiceState invoice);
}

/// Abstract repository for plans.
abstract class PlanRepository {
  const PlanRepository();

  /// Get a plan by ID.
  Future<PlanConfig?> getPlan(String planId);

  /// Get all plans.
  Future<List<PlanConfig>> getAllPlans();

  /// Get plans for a tenant.
  Future<List<PlanConfig>> getPlansForTenant(String tenantId);

  /// Save a plan.
  Future<void> savePlan(PlanConfig plan);
}

/// Abstract repository for billing audit entries.
abstract class BillingAuditRepository {
  const BillingAuditRepository();

  /// Save an audit entry.
  Future<void> saveAuditEntry(BillingAuditEntry entry);

  /// Get audit entries for a subscription.
  Future<List<BillingAuditEntry>> getEntriesForSubscription(
    String subscriptionId,
  );

  /// Get audit entries for a user.
  Future<List<BillingAuditEntry>> getEntriesForUser(String userId);

  /// Get audit entries by event type.
  Future<List<BillingAuditEntry>> getEntriesByEventType(String eventType);
}
