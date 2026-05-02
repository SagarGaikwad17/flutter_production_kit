import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/providers/auth_provider.dart';
import 'package:flutter_production_kit/auth/domain/entities/auth_provider_type.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Composite auth provider — manages multiple auth providers with fallback.
///
/// Design rationale:
/// - Primary provider handles the main auth flow.
/// - If primary is unavailable, falls back to the next available provider.
/// - Allows hybrid setups (e.g., Firebase Auth + custom JWT backend).
/// - Provider selection is explicit — no magic auto-detection.
class CompositeAuthProvider implements AuthProvider {
  CompositeAuthProvider({
    required List<AuthProvider> providers,
    required AuthProvider primary,
  })  : _providers = providers,
        _primary = primary;

  static const String _tag = 'CompositeAuthProvider';

  final List<AuthProvider> _providers;
  final AuthProvider _primary;

  @override
  AuthProviderType get type => AuthProviderType.custom;

  @override
  String get name => 'Composite';

  @override
  int get priority => 0;

  @override
  bool get isAvailable => _primary.isAvailable;

  AuthProvider get primary => _primary;

  List<AuthProvider> get allProviders => _providers;

  @override
  Future<void> initialize() async {
    for (final provider in _providers) {
      try {
        await provider.initialize();
        AppLogger.info(_tag, 'Provider initialized: ${provider.name}');
      } catch (e) {
        AppLogger.warning(_tag, 'Provider failed to initialize: ${provider.name}', error: e);
      }
    }
  }

  @override
  AuthRemoteDataSource? createRemoteDataSource() {
    if (_primary.isAvailable) {
      return _primary.createRemoteDataSource();
    }

    for (final provider in _providers) {
      if (provider != _primary && provider.isAvailable) {
        AppLogger.info(_tag, 'Primary unavailable — using fallback: ${provider.name}');
        return provider.createRemoteDataSource();
      }
    }

    AppLogger.error(_tag, 'No auth providers are available.', error: Exception('All providers unavailable'));
    return null;
  }

  @override
  Future<void> dispose() async {
    for (final provider in _providers) {
      try {
        await provider.dispose();
      } catch (e) {
        AppLogger.warning(_tag, 'Error disposing provider: ${provider.name}', error: e);
      }
    }
  }

  /// Get a specific provider by type.
  T? getProvider<T extends AuthProvider>() {
    for (final provider in _providers) {
      if (provider is T) return provider;
    }
    return null;
  }
}
