import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/entities/sync_operation.dart';

/// Sync orchestrator — executes sync operations against the backend.
///
/// Design rationale:
/// - Translates SyncOperation into an API call.
/// - Handles server responses and extracts conflict information.
/// - Returns a structured result with server version and conflict flags.
/// - Does NOT handle retries — that's the RetryScheduler's job.
/// - Does NOT handle permissions — that's the SyncEngine's job.
/// - Single responsibility: execute one operation, return the result.
///
/// In production, this would use the ApiClient from the network module.
/// For now, it defines the interface that any backend implementation must fulfill.
class SyncOrchestrator {
  SyncOrchestrator({
    required SyncOperationExecutor executor,
  }) : _executor = executor;

  static const String _tag = 'SyncOrchestrator';

  final SyncOperationExecutor _executor;

  /// Execute a sync operation against the backend.
  Future<SyncOperationResponse> execute(SyncOperation operation) async {
    AppLogger.debug(
      _tag,
      'Executing: ${operation.action.name} ${operation.resourceType}/${operation.resourceId}',
    );

    try {
      final response = await _executor.execute(operation);

      AppLogger.info(
        _tag,
        'Synced: ${operation.action.name} ${operation.resourceType}/${operation.resourceId} '
        '(version: ${response.serverVersion})',
      );

      return response;
    } catch (e) {
      AppLogger.error(
        _tag,
        'Failed to execute: ${operation.action.name} ${operation.resourceType}/${operation.resourceId}',
        error: e,
      );
      rethrow;
    }
  }
}

/// Abstract executor — the bridge between sync operations and the backend API.
///
/// Implement this to connect the offline sync engine to your specific backend.
/// The executor is responsible for:
/// - Translating SyncOperation into the appropriate HTTP call.
/// - Returning the server's response with version info.
/// - Flagging conflicts when server data differs from expected.
abstract class SyncOperationExecutor {
  const SyncOperationExecutor();

  /// Execute a sync operation and return the server response.
  ///
  /// Throws on network errors, authentication failures, etc.
  /// Returns a structured response on success.
  Future<SyncOperationResponse> execute(SyncOperation operation);
}

/// Response from a sync operation execution.
class SyncOperationResponse {
  const SyncOperationResponse({
    required this.success,
    this.serverVersion,
    this.serverPayload,
    this.hasConflict = false,
    this.errorMessage,
    this.httpStatusCode,
  });

  final bool success;
  final String? serverVersion;
  final Map<String, dynamic>? serverPayload;
  final bool hasConflict;
  final String? errorMessage;
  final int? httpStatusCode;

  factory SyncOperationResponse.success({
    String? serverVersion,
    Map<String, dynamic>? serverPayload,
  }) {
    return SyncOperationResponse(
      success: true,
      serverVersion: serverVersion,
      serverPayload: serverPayload,
    );
  }

  factory SyncOperationResponse.conflict({
    required Map<String, dynamic> serverPayload,
    String? serverVersion,
  }) {
    return SyncOperationResponse(
      success: false,
      serverVersion: serverVersion,
      serverPayload: serverPayload,
      hasConflict: true,
    );
  }

  factory SyncOperationResponse.failure({
    required String errorMessage,
    int? httpStatusCode,
  }) {
    return SyncOperationResponse(
      success: false,
      errorMessage: errorMessage,
      httpStatusCode: httpStatusCode,
    );
  }
}
