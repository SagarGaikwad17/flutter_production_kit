import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_production_kit/auth/guards/auth_guard.dart';
import 'package:flutter_production_kit/auth/guards/permission_guard.dart';
import 'package:flutter_production_kit/auth/guards/session_guard.dart';
import 'package:flutter_production_kit/auth/providers/jwt_auth_provider.dart';
import 'package:flutter_production_kit/auth/security/device_binding.dart';
import 'package:flutter_production_kit/auth/security/suspicious_login_detector.dart';
import 'package:flutter_production_kit/auth/session/refresh_lock_manager.dart';
import 'package:flutter_production_kit/auth/session/session_manager.dart';
import 'package:flutter_production_kit/auth/session/session_storage.dart';
import 'package:flutter_production_kit/auth/session/token_manager.dart';
import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_production_kit/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_production_kit/auth/domain/usecases/logout_usecase.dart';
import 'package:flutter_production_kit/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_production_kit/auth/domain/usecases/restore_session_usecase.dart';
import 'package:flutter_production_kit/auth/domain/usecases/revoke_session_usecase.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';

/// Auth module registration for GetIt dependency injection.
///
/// Design rationale:
/// - All auth dependencies are registered here in one place.
/// - Singletons are used for stateful services (SessionManager, TokenManager).
/// - Factories are used for stateless use cases.
/// - The [baseUrl] parameter allows flavor-specific API endpoints.
///
/// Usage:
/// ```dart
/// // In your app bootstrap or main function:
/// AuthModule.register(
///   getIt,
///   baseUrl: FlavorConfig.instance.env.apiBaseUrl,
///   loginRoute: '/login',
///   verificationRoute: '/verify',
/// );
/// ```
abstract final class AuthModule {
  AuthModule._();

  static const String _tag = 'AuthModule';

  static void register(
    GetIt getIt, {
    required String baseUrl,
    String loginRoute = '/login',
    String verificationRoute = '/verify',
  }) {
    AppLogger.info(_tag, 'Registering auth module...');

    // ── Core Infrastructure ──────────────────────────────────────────────────

    getIt.registerLazySingleton<SecureAuthStorage>(
      () => SecureAuthStorage(),
    );

    getIt.registerLazySingleton<DeviceBinding>(
      () => DeviceBinding(),
    );

    getIt.registerLazySingleton<SuspiciousLoginDetector>(
      () => SuspiciousLoginDetector(),
    );

    getIt.registerLazySingleton<RefreshLockManager>(
      () => RefreshLockManager(),
    );

    // ── Data Source ──────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => JwtRemoteDataSource(baseUrl: baseUrl),
    );

    // ── Repository ───────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: getIt<AuthRemoteDataSource>(),
        localDataSource: getIt<SecureAuthStorage>(),
        deviceBinding: getIt<DeviceBinding>(),
      ),
    );

    // ── Session Engine ───────────────────────────────────────────────────────

    getIt.registerLazySingleton<TokenManager>(
      () => TokenManager(
        refreshLockManager: getIt<RefreshLockManager>(),
        authRepository: getIt<AuthRepository>(),
        onSessionExpired: () {
          getIt<SessionManager>().onSessionExpired();
        },
      ),
    );

    getIt.registerLazySingleton<SessionManager>(
      () => SessionManager(
        authRepository: getIt<AuthRepository>(),
        tokenManager: getIt<TokenManager>(),
        refreshLockManager: getIt<RefreshLockManager>(),
      ),
    );

    // ── Use Cases ────────────────────────────────────────────────────────────

    getIt.registerFactory<LoginWithEmailUseCase>(
      () => LoginWithEmailUseCase(repository: getIt<AuthRepository>()),
    );

    getIt.registerFactory<LogoutUseCase>(
      () => LogoutUseCase(repository: getIt<AuthRepository>()),
    );

    getIt.registerFactory<RestoreSessionUseCase>(
      () => RestoreSessionUseCase(repository: getIt<AuthRepository>()),
    );

    getIt.registerFactory<RefreshTokenUseCase>(
      () => RefreshTokenUseCase(repository: getIt<AuthRepository>()),
    );

    getIt.registerFactory<RevokeSessionUseCase>(
      () => RevokeSessionUseCase(repository: getIt<AuthRepository>()),
    );

    // ── Guards ───────────────────────────────────────────────────────────────

    getIt.registerLazySingleton<AuthRouteGuard>(
      () => AuthRouteGuard(
        sessionManager: getIt<SessionManager>(),
        loginRoute: loginRoute,
        verificationRoute: verificationRoute,
      ),
    );

    getIt.registerLazySingleton<SessionGuard>(
      () => SessionGuard(sessionManager: getIt<SessionManager>()),
    );

    getIt.registerLazySingleton<PermissionGuard>(
      () => PermissionGuard(sessionManager: getIt<SessionManager>()),
    );

    AppLogger.info(_tag, 'Auth module registration complete.');
  }

  /// Unregister all auth dependencies — useful for testing or app teardown.
  static void unregister(GetIt getIt) {
    try {
      getIt<SessionManager>().dispose();
    } catch (_) {}

    try {
      getIt<TokenManager>().dispose();
    } catch (_) {}

    getIt.unregister<AuthRouteGuard>();
    getIt.unregister<SessionGuard>();
    getIt.unregister<PermissionGuard>();
    getIt.unregister<RevokeSessionUseCase>();
    getIt.unregister<RefreshTokenUseCase>();
    getIt.unregister<RestoreSessionUseCase>();
    getIt.unregister<LogoutUseCase>();
    getIt.unregister<LoginWithEmailUseCase>();
    getIt.unregister<SessionManager>();
    getIt.unregister<TokenManager>();
    getIt.unregister<AuthRepository>();
    getIt.unregister<AuthRemoteDataSource>();
    getIt.unregister<RefreshLockManager>();
    getIt.unregister<SuspiciousLoginDetector>();
    getIt.unregister<DeviceBinding>();
    getIt.unregister<SecureAuthStorage>();

    AppLogger.info(_tag, 'Auth module unregistered.');
  }
}
