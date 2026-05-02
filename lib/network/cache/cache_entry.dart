/// A single cache entry with versioning and metadata.
///
/// Design rationale:
/// - [version] enables cache invalidation when the schema changes.
/// - [createdAt] and [expiresAt] control freshness.
/// - [etag] supports conditional requests (If-None-Match).
/// - [lastModified] supports conditional requests (If-Modified-Since).
class CacheEntry {
  const CacheEntry({
    required this.key,
    required this.data,
    required this.statusCode,
    required this.createdAt,
    required this.expiresAt,
    this.version = 1,
    this.etag,
    this.lastModified,
    this.headers = const {},
  });

  final String key;
  final dynamic data;
  final int statusCode;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int version;
  final String? etag;
  final DateTime? lastModified;
  final Map<String, String> headers;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isStale {
    final now = DateTime.now();
    final midpoint = createdAt.add(expiresAt.difference(createdAt) ~/ 2);
    return now.isAfter(midpoint);
  }

  CacheEntry copyWith({
    dynamic data,
    int? statusCode,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? version,
    String? etag,
    DateTime? lastModified,
    Map<String, String>? headers,
  }) {
    return CacheEntry(
      key: key,
      data: data ?? this.data,
      statusCode: statusCode ?? this.statusCode,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      version: version ?? this.version,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
      headers: headers ?? this.headers,
    );
  }
}
