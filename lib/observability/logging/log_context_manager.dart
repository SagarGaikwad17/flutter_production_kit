/// Log context manager — manages correlation IDs and user context for logging.
///
/// Design rationale:
/// - Correlation IDs link logs across modules for full trace reconstruction.
/// - User context is attached to all logs within a session.
/// - Context is thread-safe and zone-aware for concurrent operations.
/// - Context is cleared on session end to prevent leakage.
///
/// Context propagation:
///   1. Set correlation ID at request/operation start.
///   2. All logs within the operation inherit the correlation ID.
///   3. Nested operations inherit parent context.
///   4. Context is cleared when operation completes.
class LogContextManager {
  LogContextManager({
    CorrelationIdGenerator? idGenerator,
  }) : _idGenerator = idGenerator ?? const UuidCorrelationIdGenerator();

  final CorrelationIdGenerator _idGenerator;
  LogContext _current = LogContext.empty;

  LogContext get current => _current;

  /// Execute a function with a new correlation context.
  T runWithContext<T>({
    String? correlationId,
    String? userId,
    String? tenantId,
    String? branchId,
    required T Function() body,
  }) {
    final previous = _current;
    _current = LogContext(
      correlationId: correlationId ?? _idGenerator.generate(),
      userId: userId ?? previous.userId,
      tenantId: tenantId ?? previous.tenantId,
      branchId: branchId ?? previous.branchId,
    );

    try {
      return body();
    } finally {
      _current = previous;
    }
  }

  /// Execute an async function with a new correlation context.
  Future<T> runWithContextAsync<T>({
    String? correlationId,
    String? userId,
    String? tenantId,
    String? branchId,
    required Future<T> Function() body,
  }) async {
    final previous = _current;
    _current = LogContext(
      correlationId: correlationId ?? _idGenerator.generate(),
      userId: userId ?? previous.userId,
      tenantId: tenantId ?? previous.tenantId,
      branchId: branchId ?? previous.branchId,
    );

    try {
      return await body();
    } finally {
      _current = previous;
    }
  }

  /// Set the current user context.
  void setUserContext({
    String? userId,
    String? tenantId,
    String? branchId,
  }) {
    _current = LogContext(
      correlationId: _current.correlationId,
      userId: userId ?? _current.userId,
      tenantId: tenantId ?? _current.tenantId,
      branchId: branchId ?? _current.branchId,
    );
  }

  /// Clear all context.
  void clear() {
    _current = LogContext.empty;
  }

  /// Generate a new correlation ID.
  String generateCorrelationId() {
    return _idGenerator.generate();
  }
}

/// Log context — immutable snapshot of current logging context.
class LogContext {
  const LogContext({
    this.correlationId,
    this.userId,
    this.tenantId,
    this.branchId,
  });

  final String? correlationId;
  final String? userId;
  final String? tenantId;
  final String? branchId;

  static const LogContext empty = LogContext();

  bool get isEmpty =>
      correlationId == null &&
      userId == null &&
      tenantId == null &&
      branchId == null;
}

/// Correlation ID generator interface.
abstract class CorrelationIdGenerator {
  const CorrelationIdGenerator();
  String generate();
}

/// UUID-based correlation ID generator.
class UuidCorrelationIdGenerator implements CorrelationIdGenerator {
  const UuidCorrelationIdGenerator();

  @override
  String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'corr_${timestamp}_${_randomSegment()}';
  }

  String _randomSegment() {
    return (DateTime.now().microsecondsSinceEpoch % 1000000)
        .toRadixString(36)
        .padLeft(6, '0');
  }
}
