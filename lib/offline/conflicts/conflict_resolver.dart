import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/offline/domain/entities/conflict_record.dart';
import 'package:flutter_production_kit/offline/conflicts/resolution_strategies.dart';

/// Conflict resolver — detects and resolves sync conflicts.
///
/// Design rationale:
/// - Maintains a registry of resolution strategies per resource type.
/// - Detects conflicts by comparing local operation payload with server response.
/// - Resolves conflicts using the registered strategy.
/// - Unresolved conflicts are stored for manual handling.
/// - All conflict activity is traced for audit purposes.
class ConflictResolver {
  ConflictResolver({
    ResolutionStrategies? strategies,
  }) : _strategies = strategies ?? const ResolutionStrategies();

  static const String _tag = 'ConflictResolver';

  final ResolutionStrategies _strategies;
  final Map<String, ConflictResolutionStrategy> _registry = {};
  final Map<String, DeleteVsUpdatePolicy> _deleteVsUpdateRegistry = {};

  /// Register a resolution strategy for a resource type.
  void registerStrategy(String resourceType, ConflictResolutionStrategy strategy) {
    _registry[resourceType] = strategy;
    AppLogger.info(_tag, 'Registered conflict strategy for "$resourceType": ${strategy.name}');
  }

  /// Register a delete-vs-update policy for a resource type.
  void registerDeleteVsUpdatePolicy(String resourceType, DeleteVsUpdatePolicy policy) {
    _deleteVsUpdateRegistry[resourceType] = policy;
  }

  /// Check if a conflict exists between local and server versions.
  bool hasConflict({
    required String resourceType,
    required String resourceId,
    required Map<String, dynamic> localPayload,
    required Map<String, dynamic> serverPayload,
  }) {
    if (localPayload.isEmpty && serverPayload.isEmpty) return false;

    for (final entry in localPayload.entries) {
      if (!serverPayload.containsKey(entry.key)) continue;
      if (serverPayload[entry.key] != entry.value) return true;
    }

    return false;
  }

  /// Resolve a conflict using the registered strategy.
  ///
  /// Returns the resolved payload if the strategy can auto-resolve.
  /// Returns null if manual resolution is required.
  ConflictResolutionResult resolve({
    required ConflictRecord conflict,
    Map<String, dynamic>? serverPayload,
    String? resolvedBy,
  }) {
    final strategy = _registry[conflict.resourceType];

    if (strategy == null) {
      AppLogger.warning(
        _tag,
        'No strategy registered for "${conflict.resourceType}" — '
        'defaulting to manual resolution.',
      );
      return ConflictResolutionResult(
        strategy: ConflictResolutionStrategy.manualResolution,
        resolvedPayload: null,
        requiresManual: true,
        description: 'No strategy registered for this resource type.',
      );
    }

    final serverData = serverPayload ?? conflict.serverVersion;

    final resolvedPayload = switch (strategy) {
      ConflictResolutionStrategy.serverWins =>
        _strategies.serverWins(
          localVersion: conflict.localVersion,
          serverVersion: serverData,
          conflict: conflict,
        ),
      ConflictResolutionStrategy.clientWins =>
        _strategies.clientWins(
          localVersion: conflict.localVersion,
          serverVersion: serverData,
          conflict: conflict,
        ),
      ConflictResolutionStrategy.mergeFields =>
        _strategies.mergeFields(
          localVersion: conflict.localVersion,
          serverVersion: serverData,
          conflict: conflict,
        ),
      ConflictResolutionStrategy.manualResolution => null,
      ConflictResolutionStrategy.localDiscarded =>
        Map<String, dynamic>.from(serverData),
    };

    final result = ConflictResolutionResult(
      strategy: strategy,
      resolvedPayload: resolvedPayload,
      requiresManual: resolvedPayload == null,
      description: 'Resolved using ${strategy.name} strategy.',
    );

    AppLogger.info(
      _tag,
      'Conflict resolved for ${conflict.resourceType}/${conflict.resourceId}: '
      '${result.description}',
    );

    return result;
  }

  /// Handle a delete-vs-update conflict.
  ResolutionDecision handleDeleteVsUpdate({
    required String resourceType,
    required String resourceId,
    required bool wasDeletedOnServer,
    required bool wasUpdatedLocally,
    required Map<String, dynamic>? localVersion,
    required Map<String, dynamic>? serverVersion,
  }) {
    final policy = _deleteVsUpdateRegistry[resourceType] ??
        DeleteVsUpdatePolicy.manual;

    return _strategies.handleDeleteVsUpdate(
      wasDeletedOnServer: wasDeletedOnServer,
      wasUpdatedLocally: wasUpdatedLocally,
      localVersion: localVersion,
      serverVersion: serverVersion,
      policy: policy,
    );
  }

  /// Get the registered strategy for a resource type.
  ConflictResolutionStrategy? getStrategy(String resourceType) {
    return _registry[resourceType];
  }
}

/// Result of a conflict resolution attempt.
class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.strategy,
    required this.resolvedPayload,
    required this.requiresManual,
    required this.description,
  });

  final ConflictResolutionStrategy strategy;
  final Map<String, dynamic>? resolvedPayload;
  final bool requiresManual;
  final String description;
}
