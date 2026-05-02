/// Pagination metadata returned from list endpoints.
///
/// Design rationale:
/// - [totalItems] enables accurate page count calculation.
/// - [hasMore] allows infinite scroll without total count.
/// - [nextCursor] supports cursor-based pagination (more scalable than offset).
/// - [page] and [pageSize] for traditional offset pagination.
class PaginationInfo {
  const PaginationInfo({
    this.totalItems,
    this.page,
    this.pageSize,
    this.hasMore,
    this.nextCursor,
    this.previousCursor,
  });

  final int? totalItems;
  final int? page;
  final int? pageSize;
  final bool? hasMore;
  final String? nextCursor;
  final String? previousCursor;

  int? get totalPages {
    if (totalItems == null || pageSize == null || pageSize == 0) return null;
    return (totalItems! / pageSize!).ceil();
  }

  bool get isOffsetBased => page != null && pageSize != null;
  bool get isCursorBased => nextCursor != null || previousCursor != null;

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      totalItems: json['total_items'] as int?,
      page: json['page'] as int?,
      pageSize: json['page_size'] as int?,
      hasMore: json['has_more'] as bool?,
      nextCursor: json['next_cursor'] as String?,
      previousCursor: json['previous_cursor'] as String?,
    );
  }
}

/// Paginated response wrapper.
///
/// Use this for feed endpoints, admin panels, and any list that supports
/// pagination. The [mergeWith] method safely combines pages without duplicates.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    this.pagination,
  });

  final List<T> items;
  final PaginationInfo? pagination;

  bool get hasMore => pagination?.hasMore ?? false;
  String? get nextCursor => pagination?.nextCursor;

  /// Merge another page into this response, deduplicating by [idSelector].
  ///
  /// This prevents duplicate items when:
  /// - Live updates insert items between page loads.
  /// - Retry returns overlapping data.
  /// - Cursor moves backward due to deletions.
  PaginatedResponse<T> mergeWith(
    PaginatedResponse<T> other, {
    required String Function(T item) idSelector,
  }) {
    final existingIds = items.map(idSelector).toSet();
    final newItems = other.items.where((item) => !existingIds.contains(idSelector(item))).toList();

    return PaginatedResponse<T>(
      items: [...items, ...newItems],
      pagination: other.pagination,
    );
  }

  /// Replace items in place by matching IDs — used for live update reconciliation.
  PaginatedResponse<T> reconcileWith(
    List<T> liveUpdates, {
    required String Function(T item) idSelector,
  }) {
    final updateMap = <String, T>{};
    for (final update in liveUpdates) {
      updateMap[idSelector(update)] = update;
    }

    final reconciled = items.map((item) {
      final id = idSelector(item);
      return updateMap[id] ?? item;
    }).toList();

    final newItems = liveUpdates.where(
      (update) => !items.any((item) => idSelector(item) == idSelector(update)),
    );

    return PaginatedResponse<T>(
      items: [...reconciled, ...newItems],
      pagination: pagination,
    );
  }
}
