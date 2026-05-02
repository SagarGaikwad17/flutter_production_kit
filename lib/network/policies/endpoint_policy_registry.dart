import 'package:flutter_production_kit/network/cache/cache_policy.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/retry/retry_policy.dart';

/// Per-endpoint policy registry — configures retry, cache, and criticality
/// for each API endpoint pattern.
///
/// Design rationale:
/// - Centralizes all endpoint policies in one place.
/// - Uses pattern matching (prefix-based) so you don't need to register
///   every single endpoint — register once per resource.
/// - Default policy applies to unregistered endpoints (conservative).
/// - Explicit overrides prevent accidental policy drift.
///
/// Usage:
/// ```dart
/// final registry = EndpointPolicyRegistry()
///   ..register('/users', criticality: EndpointCriticality.standard)
///   ..register('/payments', criticality: EndpointCriticality.critical, retryPolicy: RetryPolicy.critical)
///   ..register('/feed', criticality: EndpointCriticality.safe, cachePolicy: CachePolicy.shortLived);
/// ```
class EndpointPolicyRegistry {
  EndpointPolicyRegistry({
    RetryPolicy? defaultRetryPolicy,
    CachePolicy? defaultCachePolicy,
  })  : _defaultRetryPolicy = defaultRetryPolicy ?? RetryPolicy.standard,
        _defaultCachePolicy = defaultCachePolicy ?? CachePolicy.none;

  final RetryPolicy _defaultRetryPolicy;
  final CachePolicy _defaultCachePolicy;
  final List<_EndpointPolicy> _policies = [];

  /// Register a policy for endpoints matching the given path prefix.
  void register(
    String pathPrefix, {
    EndpointCriticality? criticality,
    RetryPolicy? retryPolicy,
    CachePolicy? cachePolicy,
  }) {
    _policies.add(_EndpointPolicy(
      pathPrefix: pathPrefix.toLowerCase(),
      criticality: criticality,
      retryPolicy: retryPolicy,
      cachePolicy: cachePolicy,
    ));
  }

  /// Resolve the criticality for a given request path.
  EndpointCriticality resolveCriticality(String path) {
    final policy = _findMatching(path);
    return policy?.criticality ?? EndpointCriticality.standard;
  }

  /// Resolve the retry policy for a given request path.
  RetryPolicy resolveRetryPolicy(String path) {
    final policy = _findMatching(path);
    return policy?.retryPolicy ?? _defaultRetryPolicy;
  }

  /// Resolve the cache policy for a given request path.
  CachePolicy resolveCachePolicy(String path) {
    final policy = _findMatching(path);
    return policy?.cachePolicy ?? _defaultCachePolicy;
  }

  _EndpointPolicy? _findMatching(String path) {
    final lowerPath = path.toLowerCase();
    // First match wins — register most specific patterns first.
    for (final policy in _policies) {
      if (lowerPath.startsWith(policy.pathPrefix) || lowerPath == policy.pathPrefix) {
        return policy;
      }
    }
    return null;
  }
}

class _EndpointPolicy {
  const _EndpointPolicy({
    required this.pathPrefix,
    this.criticality,
    this.retryPolicy,
    this.cachePolicy,
  });

  final String pathPrefix;
  final EndpointCriticality? criticality;
  final RetryPolicy? retryPolicy;
  final CachePolicy? cachePolicy;
}
