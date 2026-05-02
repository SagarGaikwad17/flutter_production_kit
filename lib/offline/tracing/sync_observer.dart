import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_status.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_trace.dart';

/// Sync observer — observability layer for the offline sync system.
///
/// Design rationale:
/// - Provides hooks for monitoring, logging, and alerting.
/// - All observability events flow through this single point.
/// - Listeners can be registered for UI updates, analytics, and alerting.
/// - NO sensitive data is emitted — only safe metadata.
/// - Structured events enable dashboards and alerting systems.
///
/// Observable events:
/// - Engine state changes (running, paused, stopped, recovering)
/// - Sync session start/complete/error
/// - Operation lifecycle (enqueued, synced, failed, poisoned)
/// - Conflict detection and resolution
/// - Queue metrics (size, growth, drain rate)
/// - Recovery events
class SyncObserver {
  SyncObserver({
    this.enableDetailedLogging = true,
  });

  static const String _tag = 'SyncObserver';

  final bool enableDetailedLogging;

  final List<SyncEventListener> _listeners = [];

  // ── Engine Lifecycle ───────────────────────────────────────────────────────

  void onEngineStateChange(SyncEngineState state) {
    _log('Engine state changed: ${state.name}');
    _emit(SyncEngineStateEvent(state));
  }

  // ── Sync Sessions ──────────────────────────────────────────────────────────

  void onSessionStart(String sessionId) {
    _log('Sync session started: $sessionId');
    _emit(SyncSessionStartEvent(sessionId));
  }

  void onSessionComplete(SyncSessionSummary summary) {
    _log('Sync session complete: $summary');
    _emit(SyncSessionCompleteEvent(summary));
  }

  void onSessionError(String sessionId, String error) {
    _log('Sync session error: $sessionId — $error');
    _emit(SyncSessionErrorEvent(sessionId, error));
  }

  // ── Operations ─────────────────────────────────────────────────────────────

  void onOperationEnqueued(SyncOperation operation) {
    _log('Operation enqueued: ${operation.action.name} '
        '${operation.resourceType}/${operation.resourceId}');
    _emit(SyncOperationEnqueuedEvent(operation));
  }

  void onOperationSynced(SyncOperation operation, {String? serverVersion}) {
    _log('Operation synced: ${operation.id} (version: $serverVersion)');
    _emit(SyncOperationSyncedEvent(operation, serverVersion));
  }

  void onOperationFailed(SyncOperation operation, String error) {
    _log('Operation failed: ${operation.id} — $error');
    _emit(SyncOperationFailedEvent(operation, error));
  }

  void onOperationPoisoned(SyncOperation operation, String reason) {
    _log('Operation poisoned: ${operation.id} — $reason');
    _emit(SyncOperationPoisonedEvent(operation, reason));
  }

  // ── Conflicts ──────────────────────────────────────────────────────────────

  void onConflictDetected(String resourceType, String resourceId) {
    _log('Conflict detected: $resourceType/$resourceId');
    _emit(SyncConflictDetectedEvent(resourceType, resourceId));
  }

  void onConflictResolved(String conflictId, String strategy) {
    _log('Conflict resolved: $conflictId — $strategy');
    _emit(SyncConflictResolvedEvent(conflictId, strategy));
  }

  // ── Recovery ───────────────────────────────────────────────────────────────

  void onRecoveryStart(String sessionId) {
    _log('Recovery started: $sessionId');
    _emit(SyncRecoveryStartEvent(sessionId));
  }

  void onRecoveryComplete(String sessionId, int operationsProcessed) {
    _log('Recovery complete: $sessionId ($operationsProcessed ops processed)');
    _emit(SyncRecoveryCompleteEvent(sessionId, operationsProcessed));
  }

  // ── Queue Metrics ──────────────────────────────────────────────────────────

  void onQueueMetrics({
    required int pendingCount,
    required int inProgressCount,
    required int poisonCount,
    required int conflictCount,
  }) {
    _log('Queue metrics — pending: $pendingCount, inProgress: $inProgressCount, '
        'poison: $poisonCount, conflicts: $conflictCount');
    _emit(SyncQueueMetricsEvent(
      pendingCount: pendingCount,
      inProgressCount: inProgressCount,
      poisonCount: poisonCount,
      conflictCount: conflictCount,
    ));
  }

  // ── Listener Management ────────────────────────────────────────────────────

  void addListener(SyncEventListener listener) {
    _listeners.add(listener);
  }

  void removeListener(SyncEventListener listener) {
    _listeners.remove(listener);
  }

  void clearListeners() {
    _listeners.clear();
  }

  void _emit(SyncEvent event) {
    for (final listener in _listeners) {
      listener.onSyncEvent(event);
    }
  }

  void _log(String message) {
    if (enableDetailedLogging) {
      AppLogger.debug(_tag, message);
    }
  }
}

/// Abstract listener for sync events.
abstract class SyncEventListener {
  void onSyncEvent(SyncEvent event);
}

/// Base class for all sync events.
sealed class SyncEvent {
  const SyncEvent();
}

final class SyncEngineStateEvent extends SyncEvent {
  const SyncEngineStateEvent(this.state);
  final SyncEngineState state;
}

final class SyncSessionStartEvent extends SyncEvent {
  const SyncSessionStartEvent(this.sessionId);
  final String sessionId;
}

final class SyncSessionCompleteEvent extends SyncEvent {
  const SyncSessionCompleteEvent(this.summary);
  final SyncSessionSummary summary;
}

final class SyncSessionErrorEvent extends SyncEvent {
  const SyncSessionErrorEvent(this.sessionId, this.error);
  final String sessionId;
  final String error;
}

final class SyncOperationEnqueuedEvent extends SyncEvent {
  const SyncOperationEnqueuedEvent(this.operation);
  final SyncOperation operation;
}

final class SyncOperationSyncedEvent extends SyncEvent {
  const SyncOperationSyncedEvent(this.operation, this.serverVersion);
  final SyncOperation operation;
  final String? serverVersion;
}

final class SyncOperationFailedEvent extends SyncEvent {
  const SyncOperationFailedEvent(this.operation, this.error);
  final SyncOperation operation;
  final String error;
}

final class SyncOperationPoisonedEvent extends SyncEvent {
  const SyncOperationPoisonedEvent(this.operation, this.reason);
  final SyncOperation operation;
  final String reason;
}

final class SyncConflictDetectedEvent extends SyncEvent {
  const SyncConflictDetectedEvent(this.resourceType, this.resourceId);
  final String resourceType;
  final String resourceId;
}

final class SyncConflictResolvedEvent extends SyncEvent {
  const SyncConflictResolvedEvent(this.conflictId, this.strategy);
  final String conflictId;
  final String strategy;
}

final class SyncRecoveryStartEvent extends SyncEvent {
  const SyncRecoveryStartEvent(this.sessionId);
  final String sessionId;
}

final class SyncRecoveryCompleteEvent extends SyncEvent {
  const SyncRecoveryCompleteEvent(this.sessionId, this.operationsProcessed);
  final String sessionId;
  final int operationsProcessed;
}

final class SyncQueueMetricsEvent extends SyncEvent {
  const SyncQueueMetricsEvent({
    required this.pendingCount,
    required this.inProgressCount,
    required this.poisonCount,
    required this.conflictCount,
  });

  final int pendingCount;
  final int inProgressCount;
  final int poisonCount;
  final int conflictCount;
}
