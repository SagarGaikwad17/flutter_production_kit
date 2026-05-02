import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/auth/session/token_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/network/cache/cache_manager.dart';
import 'package:flutter_production_kit/network/cache/cache_policy.dart';
import 'package:flutter_production_kit/network/client/api_client.dart';
import 'package:flutter_production_kit/network/deduplication/request_deduplicator.dart';
import 'package:flutter_production_kit/network/guards/dangerous_endpoint_guard.dart';
import 'package:flutter_production_kit/network/interceptors/auth_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/cache_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/idempotency_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/logging_interceptor.dart';
import 'package:flutter_production_kit/network/interceptors/retry_interceptor.dart';
import 'package:flutter_production_kit/network/models/api_request.dart';
import 'package:flutter_production_kit/network/policies/endpoint_policy_registry.dart';
import 'package:flutter_production_kit/network/retry/retry_engine.dart';
import 'package:flutter_production_kit/network/retry/retry_policy.dart';
import 'package:flutter_production_kit/network/tracing/network_observer.dart';
import 'package:get_it/get_it.dart';

/// Network module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All network dependencies registered in one place.
/// - Singletons for stateful services (CacheManager, Deduplicator, Observer).
/// - ApiClient is a singleton — only one HTTP client instance.
/// - [baseUrl] comes from flavor config.
/// - [setupDefaultPolicies] registers sensible defaults for common endpoints.
///
/// Usage:
/// ```dart
/// NetworkModule.register(
///   getIt,
///   baseUrl: FlavorConfig.instance.env.apiBaseUrl,
/// );
///
/// // Later in code:
/// final api = getIt<ApiClient>();
/// final response = await api.get(path: '/users/me');
/// ```
abstract final class NetworkModule {
  NetworkModule._();

  static const String _tag = 'NetworkModule';

  static void register(
    GetIt getIt, {
    required String baseUrl,
    Duration? defaultTimeout,
    bool setupDefaultPolicies = true,
  }) {
    AppLogger.info(_tag, 'Registering network module...');

    // ── HTTP Client ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<http.Client>(
      () => http.Client(),
    );

    // ── Core Services ────────────────────────────────────────────────────────

    getIt.registerLazySingleton<CacheManager>(
      () => CacheManager(),
    );

    getIt.registerLazySingleton<RequestDeduplicator>(
      () => RequestDeduplicator(),
    );

    getIt.registerLazySingleton<NetworkObserver>(
      () => NetworkObserver(),
    );

    // ── Policies ─────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<EndpointPolicyRegistry>(
      () {
        final registry = EndpointPolicyRegistry(
          defaultRetryPolicy: RetryPolicy.standard,
          defaultCachePolicy: CachePolicy.none,
        );

        if (setupDefaultPolicies) {
          _registerDefaultPolicies(registry);
        }

        return registry;
      },
    );

    getIt.registerLazySingleton<RetryEngine>(
      () => RetryEngine(),
    );

    getIt.registerLazySingleton<DangerousEndpointGuard>(
      () => DangerousEndpointGuard(),
    );

    // ── Interceptors ─────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuthInterceptor>(
      () => AuthInterceptor(
        tokenManager: getIt<TokenManager>(),
      ),
    );

    getIt.registerLazySingleton<RetryInterceptor>(
      () => RetryInterceptor(
        retryEngine: getIt<RetryEngine>(),
      ),
    );

    getIt.registerLazySingleton<CacheInterceptor>(
      () => CacheInterceptor(
        cacheManager: getIt<CacheManager>(),
        observer: getIt<NetworkObserver>(),
      ),
    );

    getIt.registerLazySingleton<IdempotencyInterceptor>(
      () => IdempotencyInterceptor(),
    );

    getIt.registerLazySingleton<LoggingInterceptor>(
      () => LoggingInterceptor(),
    );

    // ── API Client ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(
        baseUrl: baseUrl,
        httpClient: getIt<http.Client>(),
        authInterceptor: getIt<AuthInterceptor>(),
        retryInterceptor: getIt<RetryInterceptor>(),
        cacheInterceptor: getIt<CacheInterceptor>(),
        idempotencyInterceptor: getIt<IdempotencyInterceptor>(),
        loggingInterceptor: getIt<LoggingInterceptor>(),
        endpointGuard: getIt<DangerousEndpointGuard>(),
        deduplicator: getIt<RequestDeduplicator>(),
        cacheManager: getIt<CacheManager>(),
        policyRegistry: getIt<EndpointPolicyRegistry>(),
        observer: getIt<NetworkObserver>(),
        defaultTimeout: defaultTimeout,
      ),
    );

    AppLogger.info(_tag, 'Network module registration complete.');
  }

  static void _registerDefaultPolicies(EndpointPolicyRegistry registry) {
    // Safe GET endpoints — can be cached and retried.
    registry.register(
      '/feed',
      criticality: EndpointCriticality.safe,
      cachePolicy: CachePolicy.shortLived,
    );

    registry.register(
      '/users',
      criticality: EndpointCriticality.safe,
      cachePolicy: CachePolicy.medium,
    );

    registry.register(
      '/config',
      criticality: EndpointCriticality.safe,
      cachePolicy: CachePolicy.longLived,
    );

    // Payment endpoints — critical, no auto-retry.
    registry.register(
      '/payments',
      criticality: EndpointCriticality.critical,
      retryPolicy: RetryPolicy.critical,
    );

    registry.register(
      '/charges',
      criticality: EndpointCriticality.critical,
      retryPolicy: RetryPolicy.critical,
    );

    registry.register(
      '/subscriptions',
      criticality: EndpointCriticality.critical,
      retryPolicy: RetryPolicy.critical,
    );

    // Destructive endpoints — single attempt only.
    registry.register(
      '/sessions',
      criticality: EndpointCriticality.destructive,
      retryPolicy: RetryPolicy.never,
    );

    registry.register(
      '/devices',
      criticality: EndpointCriticality.destructive,
      retryPolicy: RetryPolicy.never,
    );
  }

  /// Unregister all network dependencies.
  static void unregister(GetIt getIt) {
    try {
      getIt<NetworkObserver>().dispose();
    } catch (_) {}

    getIt.unregister<ApiClient>();
    getIt.unregister<LoggingInterceptor>();
    getIt.unregister<IdempotencyInterceptor>();
    getIt.unregister<CacheInterceptor>();
    getIt.unregister<RetryInterceptor>();
    getIt.unregister<AuthInterceptor>();
    getIt.unregister<DangerousEndpointGuard>();
    getIt.unregister<RetryEngine>();
    getIt.unregister<EndpointPolicyRegistry>();
    getIt.unregister<NetworkObserver>();
    getIt.unregister<RequestDeduplicator>();
    getIt.unregister<CacheManager>();
    getIt.unregister<http.Client>();

    AppLogger.info(_tag, 'Network module unregistered.');
  }
}
