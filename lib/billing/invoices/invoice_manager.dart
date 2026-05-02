import 'package:flutter_production_kit/billing/domain/entities/invoice_state.dart';
import 'package:flutter_production_kit/billing/domain/exceptions/billing_exception.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Invoice manager — manages invoice lifecycle and idempotent creation.
///
/// Design rationale:
/// - Invoices are created idempotently — duplicate requests return existing invoice.
/// - Invoice state machine: draft → open → paid/void/uncollectible.
/// - Tracks payment provider references for reconciliation.
/// - NO sensitive card data stored — only references.
///
/// Invoice flow:
///   1. Create invoice (idempotent by idempotencyKey).
///   2. Invoice is in 'open' state.
///   3. Payment succeeds → mark as paid.
///   4. Payment fails → keep open for retry.
///   5. After max retries → mark as uncollectible.
class InvoiceManager {
  InvoiceManager({
    required InvoiceRepository invoiceRepository,
  }) : _invoiceRepository = invoiceRepository;

  static const String _tag = 'InvoiceManager';

  final InvoiceRepository _invoiceRepository;

  /// Create an invoice (idempotent).
  Future<InvoiceState> createInvoice({
    required String invoiceId,
    required String subscriptionId,
    required String userId,
    required int amountCents,
    required String currency,
    required String idempotencyKey,
    required List<InvoiceLineItem> lineItems,
    DateTime? dueAt,
    Map<String, String>? metadata,
  }) async {
    // Check for existing invoice with same idempotency key.
    final existing = await _invoiceRepository.getInvoiceByIdempotencyKey(idempotencyKey);
    if (existing != null) {
      AppLogger.info(_tag, 'Duplicate invoice request — returning existing: ${existing.id}');
      return existing;
    }

    final invoice = InvoiceState(
      id: invoiceId,
      subscriptionId: subscriptionId,
      userId: userId,
      amountCents: amountCents,
      currency: currency,
      status: InvoiceStatus.open,
      createdAt: DateTime.now(),
      dueAt: dueAt,
      idempotencyKey: idempotencyKey,
      lineItems: lineItems,
      metadata: metadata ?? {},
    );

    await _invoiceRepository.saveInvoice(invoice);
    AppLogger.info(_tag, 'Invoice created: $invoiceId ($amountCents $currency)');
    return invoice;
  }

  /// Mark invoice as paid.
  Future<InvoiceState> markPaid({
    required String invoiceId,
    required String paymentProviderReference,
    String? initiatedBy,
  }) async {
    final invoice = await _getInvoice(invoiceId);

    if (invoice.isPaid) {
      AppLogger.info(_tag, 'Invoice already paid: $invoiceId');
      return invoice;
    }

    final updated = InvoiceState(
      id: invoice.id,
      subscriptionId: invoice.subscriptionId,
      userId: invoice.userId,
      amountCents: invoice.amountCents,
      currency: invoice.currency,
      status: InvoiceStatus.paid,
      createdAt: invoice.createdAt,
      dueAt: invoice.dueAt,
      paidAt: DateTime.now(),
      paymentProviderReference: paymentProviderReference,
      idempotencyKey: invoice.idempotencyKey,
      lineItems: invoice.lineItems,
      metadata: invoice.metadata,
    );

    await _invoiceRepository.updateInvoice(updated);
    AppLogger.info(_tag, 'Invoice paid: $invoiceId (ref: $paymentProviderReference)');
    return updated;
  }

  /// Mark invoice as void.
  Future<InvoiceState> markVoid({
    required String invoiceId,
    required String reason,
    String? initiatedBy,
  }) async {
    final invoice = await _getInvoice(invoiceId);

    if (invoice.isPaid) {
      throw InvoiceNotFoundException(
        message: 'Cannot void a paid invoice: $invoiceId',
        invoiceId: invoiceId,
      );
    }

    final updated = InvoiceState(
      id: invoice.id,
      subscriptionId: invoice.subscriptionId,
      userId: invoice.userId,
      amountCents: invoice.amountCents,
      currency: invoice.currency,
      status: InvoiceStatus.voided,
      createdAt: invoice.createdAt,
      dueAt: invoice.dueAt,
      paidAt: invoice.paidAt,
      paymentProviderReference: invoice.paymentProviderReference,
      idempotencyKey: invoice.idempotencyKey,
      lineItems: invoice.lineItems,
      metadata: {
        ...invoice.metadata,
        'void_reason': reason,
        'voided_by': initiatedBy ?? 'system',
      },
    );

    await _invoiceRepository.updateInvoice(updated);
    AppLogger.info(_tag, 'Invoice voided: $invoiceId (reason: $reason)');
    return updated;
  }

  /// Get invoice by ID.
  Future<InvoiceState?> getInvoice(String invoiceId) {
    return _invoiceRepository.getInvoice(invoiceId);
  }

  /// Get invoices for a subscription.
  Future<List<InvoiceState>> getInvoicesForSubscription(String subscriptionId) {
    return _invoiceRepository.getInvoicesForSubscription(subscriptionId);
  }

  /// Get invoices for a user.
  Future<List<InvoiceState>> getInvoicesForUser(String userId) {
    return _invoiceRepository.getInvoicesForUser(userId);
  }

  /// Get overdue invoices for a user.
  Future<List<InvoiceState>> getOverdueInvoices(String userId) async {
    final invoices = await _invoiceRepository.getInvoicesForUser(userId);
    return invoices.where((inv) => inv.isOverdue).toList();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<InvoiceState> _getInvoice(String id) async {
    final invoice = await _invoiceRepository.getInvoice(id);
    if (invoice == null) {
      throw InvoiceNotFoundException(
        message: 'Invoice not found: $id',
        invoiceId: id,
      );
    }
    return invoice;
  }
}
