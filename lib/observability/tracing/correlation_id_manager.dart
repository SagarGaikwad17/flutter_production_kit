/// Correlation ID manager — manages correlation IDs for cross-module tracing.
///
/// Design rationale:
/// - Correlation IDs link logs, traces, and audit entries across modules.
/// - Each operation gets a unique correlation ID.
/// - IDs are propagated through the call stack.
/// - IDs are cleared when the operation completes.
/// - Integration with external systems (payment gateways, etc.).
class CorrelationIdManager {
  CorrelationIdManager({
    CorrelationIdGenerator? idGenerator,
  }) : _idGenerator = idGenerator ?? const DefaultCorrelationIdGenerator();

  final CorrelationIdGenerator _idGenerator;
  String? _current;

  String? get current => _current;

  /// Set the current correlation ID.
  void setCurrent(String correlationId) {
    _current = correlationId;
  }

  /// Generate a new correlation ID.
  String generate() {
    return _idGenerator.generate();
  }

  /// Execute a function with a correlation ID context.
  T runWithId<T>(String correlationId, T Function() body) {
    final previous = _current;
    _current = correlationId;
    try {
      return body();
    } finally {
      _current = previous;
    }
  }

  /// Execute an async function with a correlation ID context.
  Future<T> runWithIdAsync<T>(String correlationId, Future<T> Function() body) async {
    final previous = _current;
    _current = correlationId;
    try {
      return await body();
    } finally {
      _current = previous;
    }
  }

  /// Clear the current correlation ID.
  void clear() {
    _current = null;
  }
}

/// Correlation ID generator interface.
abstract class CorrelationIdGenerator {
  const CorrelationIdGenerator();
  String generate();
}

/// Default correlation ID generator.
class DefaultCorrelationIdGenerator implements CorrelationIdGenerator {
  const DefaultCorrelationIdGenerator();

  @override
  String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (DateTime.now().microsecondsSinceEpoch % 1000000)
        .toRadixString(36)
        .padLeft(6, '0');
    return 'trace_${timestamp}_$random';
  }
}
