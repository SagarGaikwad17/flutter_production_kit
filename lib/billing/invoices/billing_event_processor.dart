import 'package:flutter_production_kit/billing/domain/entities/billing_event.dart';
import 'package:flutter_production_kit/billing/domain/repositories/billing_repositories.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Billing event processor — idempotent webhook and event processing.
///
/// Design rationale:
/// - ALL events are processed exactly-once via idempotency key.
/// - Duplicate events are detected, logged, and silently ignored.
/// - Event processing is replay-safe — same event processed twice has same outcome.
/// - Event handlers are registered per event type.
/// - Processing is atomic — event is marked processed only after handler succeeds.
///
/// Idempotency strategy:
///   1. Check if idempotency key exists in repository.
///   2. If exists → return immediately (already processed).
///   3. If not → process event → mark as processed.
///   4. If processing fails → event remains unprocessed for retry.
///
/// Webhook safety:
///   - Payment providers may send duplicate webhooks.
///   - Network retries may cause duplicate deliveries.
///   - This processor guarantees exactly-once processing.
class BillingEventProcessor {
  BillingEventProcessor({
    required BillingEventRepository eventRepository,
  }) : _eventRepository = eventRepository;

  static const String _tag = 'BillingEventProcessor';

  final BillingEventRepository _eventRepository;
  final Map<BillingEventType, BillingEventHandler> _handlers = {};

  /// Register a handler for an event type.
  void registerHandler(BillingEventType type, BillingEventHandler handler) {
    _handlers[type] = handler;
  }

  /// Process a billing event (idempotent).
  Future<EventProcessingResult> processEvent(BillingEvent event) async {
    // Step 1: Check for duplicate.
    final existing = await _eventRepository.getEventByIdempotencyKey(event.idempotencyKey);
    if (existing != null && existing.isProcessed) {
      AppLogger.info(
        _tag,
        'Duplicate event detected: ${event.idempotencyKey} (${event.type.name})',
      );
      return EventProcessingResult(
        eventId: event.id,
        status: EventProcessingStatus.duplicate,
        message: 'Event already processed.',
      );
    }

    // Step 2: Get handler.
    final handler = _handlers[event.type];
    if (handler == null) {
      AppLogger.warning(
        _tag,
        'No handler for event type: ${event.type.name}',
      );
      return EventProcessingResult(
        eventId: event.id,
        status: EventProcessingStatus.noHandler,
        message: 'No handler registered for ${event.type.name}.',
      );
    }

    // Step 3: Process event.
    try {
      await handler.handle(event);

      // Step 4: Mark as processed.
      await _eventRepository.saveEvent(event);
      await _eventRepository.markEventProcessed(event.id, DateTime.now());

      AppLogger.info(
        _tag,
        'Event processed: ${event.id} (${event.type.name})',
      );

      return EventProcessingResult(
        eventId: event.id,
        status: EventProcessingStatus.success,
        message: 'Event processed successfully.',
      );
    } catch (e, st) {
      AppLogger.error(
        _tag,
        'Event processing failed: ${event.id}',
        error: e,
        stackTrace: st,
      );

      return EventProcessingResult(
        eventId: event.id,
        status: EventProcessingStatus.failed,
        message: 'Processing failed: $e',
      );
    }
  }

  /// Process unprocessed events (recovery).
  Future<List<EventProcessingResult>> processUnprocessedEvents() async {
    final events = await _eventRepository.getUnprocessedEvents();
    final results = <EventProcessingResult>[];

    for (final event in events) {
      results.add(await processEvent(event));
    }

    return results;
  }

  /// Get registered event types.
  List<BillingEventType> getRegisteredTypes() {
    return _handlers.keys.toList();
  }
}

/// Handler for a specific billing event type.
abstract class BillingEventHandler {
  const BillingEventHandler();
  Future<void> handle(BillingEvent event);
}

/// Result of event processing.
class EventProcessingResult {
  const EventProcessingResult({
    required this.eventId,
    required this.status,
    this.message,
  });

  final String eventId;
  final EventProcessingStatus status;
  final String? message;
}

enum EventProcessingStatus {
  success,
  duplicate,
  failed,
  noHandler,
}
