/// Invoice state — tracks invoice lifecycle.
///
/// Design rationale:
/// - [id] is the unique invoice identifier.
/// - [subscriptionId] links to the subscription.
/// - [amountCents] is the billed amount in smallest currency unit.
/// - [status] tracks the invoice state machine.
/// - [idempotencyKey] prevents duplicate invoice creation.
/// - [lineItems] describes what's being billed.
/// - No sensitive card data stored — only references.
class InvoiceState {
  const InvoiceState({
    required this.id,
    required this.subscriptionId,
    required this.userId,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.idempotencyKey,
    this.dueAt,
    this.paidAt,
    this.paymentProviderReference,
    this.lineItems = const [],
    this.metadata = const {},
  });

  final String id;
  final String subscriptionId;
  final String userId;
  final int amountCents;
  final String currency;
  final InvoiceStatus status;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final String? paymentProviderReference;
  final String idempotencyKey;
  final List<InvoiceLineItem> lineItems;
  final Map<String, String> metadata;

  bool get isPaid => status == InvoiceStatus.paid;
  bool get isOverdue {
    final due = dueAt;
    return due != null && DateTime.now().isAfter(due) && !isPaid;
  }
}

enum InvoiceStatus {
  draft,
  open,
  paid,
  voided,
  uncollectible,
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.amountCents,
    this.quantity = 1,
    this.planId,
  });

  final String description;
  final int amountCents;
  final int quantity;
  final String? planId;
}
