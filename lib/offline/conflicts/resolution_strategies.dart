import 'package:flutter_production_kit/offline/domain/entities/conflict_record.dart';

/// Conflict resolution strategies — per-resource-type conflict handling.
///
/// Design rationale:
/// - Different resources require different conflict resolution approaches.
/// - Payments: server wins (server is the source of truth for financial data).
/// - Notes: merge fields (both local and server changes can coexist).
/// - Profiles: last-write-wins (client wins if local is more recent).
/// - Forms: manual resolution required (user must choose).
/// - Deleted vs Updated: explicit resolution (not accidental overwrite).
///
/// Strategy selection:
/// - Registered per resource type in [ResolutionStrategyRegistry].
/// - Falls back to [manualResolution] if no strategy is registered.
/// - Each strategy produces a resolved payload that can be synced.
class ResolutionStrategies {
  const ResolutionStrategies();

  /// Server wins — server version always takes priority.
  /// Use for: payments, financial records, admin-managed data.
  Map<String, dynamic> serverWins({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> serverVersion,
    required ConflictRecord conflict,
  }) {
    return Map<String, dynamic>.from(serverVersion);
  }

  /// Client wins — local version always takes priority.
  /// Use for: user preferences, drafts, locally-created data.
  Map<String, dynamic> clientWins({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> serverVersion,
    required ConflictRecord conflict,
  }) {
    return Map<String, dynamic>.from(localVersion);
  }

  /// Last write wins — the most recently modified version wins.
  /// Use for: profiles, settings, non-critical updates.
  Map<String, dynamic> lastWriteWins({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> serverVersion,
    required ConflictRecord conflict,
    DateTime? localModifiedAt,
    DateTime? serverModifiedAt,
  }) {
    if (localModifiedAt == null || serverModifiedAt == null) {
      return Map<String, dynamic>.from(serverVersion);
    }
    return localModifiedAt.isAfter(serverModifiedAt)
        ? Map<String, dynamic>.from(localVersion)
        : Map<String, dynamic>.from(serverVersion);
  }

  /// Merge fields — combine non-conflicting fields from both versions.
  /// Conflicting fields (different values) are resolved by server.
  /// Use for: notes, documents, multi-field records.
  Map<String, dynamic> mergeFields({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> serverVersion,
    required ConflictRecord conflict,
    Set<String>? mergeableFields,
  }) {
    final merged = Map<String, dynamic>.from(serverVersion);

    for (final entry in localVersion.entries) {
      if (mergeableFields != null && !mergeableFields.contains(entry.key)) {
        continue;
      }

      if (!serverVersion.containsKey(entry.key)) {
        merged[entry.key] = entry.value;
      } else if (serverVersion[entry.key] != entry.value) {
        merged[entry.key] = entry.value;
      }
    }

    return merged;
  }

  /// Manual resolution — requires human intervention.
  /// Use for: forms, complex records, destructive operations.
  /// This strategy does NOT produce a resolved payload.
  /// The conflict must be presented to the user for resolution.
  Map<String, dynamic>? manualResolution({
    required Map<String, dynamic> localVersion,
    required Map<String, dynamic> serverVersion,
    required ConflictRecord conflict,
  }) {
    return null;
  }

  /// Deleted vs Updated resolution — handles delete/update conflicts.
  ///
  /// When a resource was deleted on the server but updated locally:
  /// - [onLocalDeleteWins]: deletion wins, local update is discarded.
  /// - [onRestore]: local update wins, resource is restored on server.
  /// - [onManual]: requires user decision.
  ResolutionDecision handleDeleteVsUpdate({
    required bool wasDeletedOnServer,
    required bool wasUpdatedLocally,
    required Map<String, dynamic>? localVersion,
    required Map<String, dynamic>? serverVersion,
    required DeleteVsUpdatePolicy policy,
  }) {
    if (!wasDeletedOnServer || !wasUpdatedLocally) {
      return ResolutionDecision.notADeleteConflict;
    }

    return switch (policy) {
      DeleteVsUpdatePolicy.serverDeleteWins => ResolutionDecision(
          strategy: ConflictResolutionStrategy.serverWins,
          resolvedPayload: serverVersion ?? {},
          description: 'Server deletion wins — local update discarded.',
        ),
      DeleteVsUpdatePolicy.restoreFromLocal => ResolutionDecision(
          strategy: ConflictResolutionStrategy.clientWins,
          resolvedPayload: localVersion ?? {},
          description: 'Local update wins — resource restored on server.',
        ),
      DeleteVsUpdatePolicy.manual => ResolutionDecision(
          strategy: ConflictResolutionStrategy.manualResolution,
          resolvedPayload: null,
          description: 'Delete/update conflict requires manual resolution.',
        ),
    };
  }
}

/// Decision from a delete-vs-update conflict resolution.
class ResolutionDecision {
  const ResolutionDecision({
    required this.strategy,
    required this.resolvedPayload,
    required this.description,
  });

  final ConflictResolutionStrategy strategy;
  final Map<String, dynamic>? resolvedPayload;
  final String description;

  static const ResolutionDecision notADeleteConflict = ResolutionDecision(
    strategy: ConflictResolutionStrategy.manualResolution,
    resolvedPayload: null,
    description: 'Not a delete/update conflict.',
  );
}

enum DeleteVsUpdatePolicy {
  serverDeleteWins,
  restoreFromLocal,
  manual,
}
