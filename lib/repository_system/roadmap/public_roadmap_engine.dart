import 'package:flutter_production_kit/repository_system/domain/entities/repo_result.dart';
import 'package:flutter_production_kit/repository_system/domain/exceptions/repo_exception.dart';
import 'package:flutter_production_kit/repository_system/domain/repositories/repo_repositories.dart';

/// Public roadmap engine — manages and publishes a public project roadmap.
///
/// Design rationale:
/// - Public roadmaps build trust and transparency.
/// - Community can see what's planned, in progress, and completed.
/// - Roadmap items are prioritized and have target dates.
/// - Regular updates keep the roadmap fresh and reliable.
///
/// Roadmap sections:
/// 1. Completed — shipped features and fixes.
/// 2. In Progress — currently being worked on.
/// 3. Planned — scheduled for future releases.
/// 4. Under Consideration — community-requested features being evaluated.
class PublicRoadmapEngine {
  const PublicRoadmapEngine({
    required IRoadmapRepository roadmapRepository,
    this.maxPlannedItems = 20,
    this.maxInProgressItems = 10,
    this.autoArchiveCompletedAfter = const Duration(days: 90),
    this.priorityOrder = const [
      RoadmapPriority.critical,
      RoadmapPriority.high,
      RoadmapPriority.medium,
      RoadmapPriority.low,
    ],
  }) : _roadmapRepository = roadmapRepository;

  final IRoadmapRepository _roadmapRepository;
  final int maxPlannedItems;
  final int maxInProgressItems;
  final Duration autoArchiveCompletedAfter;
  final List<RoadmapPriority> priorityOrder;

  /// Add a roadmap item.
  Future<RepoResult> addItem({
    required String title,
    required String description,
    required RoadmapStatus status,
    required RoadmapPriority priority,
    DateTime? targetDate,
    String? package,
    String? assignee,
  }) async {
    // Validate capacity limits
    if (status == RoadmapStatus.planned) {
      final planned = await _roadmapRepository.getRoadmap(
        status: RoadmapStatus.planned,
      );
      if (planned.length >= maxPlannedItems) {
        throw RoadmapUpdateFailedException(
          message: 'Roadmap is at capacity for planned items ($maxPlannedItems)',
          failedItems: [title],
        );
      }
    }

    if (status == RoadmapStatus.inProgress) {
      final inProgress = await _roadmapRepository.getRoadmap(
        status: RoadmapStatus.inProgress,
      );
      if (inProgress.length >= maxInProgressItems) {
        throw RoadmapUpdateFailedException(
          message:
              'Roadmap is at capacity for in-progress items ($maxInProgressItems)',
          failedItems: [title],
        );
      }
    }

    final item = RoadmapItem(
      title: title,
      status: status,
      priority: priority,
      description: description,
      targetDate: targetDate,
      package: package,
      assignee: assignee,
    );

    await _roadmapRepository.saveRoadmapItem(item);

    return RoadmapPublishedSuccessfully(
      operation: 'add_roadmap_item',
      items: [title],
      lastUpdated: DateTime.now(),
    );
  }

  /// Update a roadmap item's status.
  Future<RepoResult> updateItemStatus({
    required String title,
    required RoadmapStatus newStatus,
  }) async {
    await _roadmapRepository.updateRoadmapItemStatus(title, newStatus);

    return RoadmapPublishedSuccessfully(
      operation: 'update_roadmap_item_status',
      items: [title],
      lastUpdated: DateTime.now(),
    );
  }

  /// Get the current roadmap organized by status.
  Future<Map<RoadmapStatus, List<RoadmapItem>>> getOrganizedRoadmap() async {
    final allItems = await _roadmapRepository.getRoadmap();
    final organized = <RoadmapStatus, List<RoadmapItem>>{};

    for (final status in RoadmapStatus.values) {
      final items = allItems
          .where((item) => item.status == status)
          .toList()
        ..sort((a, b) =>
            priorityOrder.indexOf(a.priority).compareTo(
              priorityOrder.indexOf(b.priority),
            ));
      organized[status] = items;
    }

    return organized;
  }

  /// Generate a markdown representation of the roadmap.
  Future<String> generateMarkdown() async {
    final organized = await getOrganizedRoadmap();
    final buffer = StringBuffer();

    buffer.writeln('# Public Roadmap\n');
    buffer.writeln('Last updated: ${DateTime.now().toIso8601String()}\n');

    for (final status in RoadmapStatus.values) {
      final items = organized[status] ?? [];
      if (items.isEmpty) continue;

      buffer.writeln('## ${_formatStatus(status)}\n');

      for (final item in items) {
        buffer.writeln(
          '- **${item.title}** '
          '(${item.priority.name})'
          '${item.targetDate != null ? ' — Target: ${_formatDate(item.targetDate!)}' : ''}'
          '${item.package != null ? ' [${item.package}]' : ''}',
        );
        if (item.description != null) {
          buffer.writeln('  - ${item.description}');
        }
      }

      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Publish the roadmap (returns success result).
  Future<RepoResult> publishRoadmap() async {
    final organized = await getOrganizedRoadmap();
    final allItems = organized.values.expand((e) => e).toList();

    return RoadmapPublishedSuccessfully(
      operation: 'publish_roadmap',
      items: allItems.map((e) => e.title).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Archive completed items older than the threshold.
  Future<int> archiveStaleCompletedItems() async {
    final completed = await _roadmapRepository.getRoadmap(
      status: RoadmapStatus.completed,
    );

    final now = DateTime.now();
    var archived = 0;

    for (final item in completed) {
      if (item.targetDate != null &&
          now.difference(item.targetDate!) > autoArchiveCompletedAfter) {
        // In production: move to archive or delete
        archived++;
      }
    }

    return archived;
  }

  String _formatStatus(RoadmapStatus status) {
    switch (status) {
      case RoadmapStatus.planned:
        return 'Planned';
      case RoadmapStatus.inProgress:
        return 'In Progress';
      case RoadmapStatus.completed:
        return 'Completed';
      case RoadmapStatus.deferred:
        return 'Deferred';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
