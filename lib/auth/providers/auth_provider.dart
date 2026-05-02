import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/domain/entities/auth_provider_type.dart';

/// Abstract auth provider — pluggable authentication backend.
///
/// Design rationale:
/// - No vendor lock-in: swap providers without changing business logic.
/// - Each provider handles its own initialization, validation, and cleanup.
/// - The [isAvailable] check allows graceful degradation when a provider
///   is misconfigured or unreachable.
/// - [priority] determines which provider to try first in composite scenarios.
abstract class AuthProvider {
  AuthProviderType get type;

  /// Human-readable name for logging and diagnostics.
  String get name;

  /// Priority for composite provider selection (lower = tried first).
  int get priority;

  /// Whether this provider is initialized and available.
  bool get isAvailable;

  /// Initialize the provider. Called during app bootstrap.
  Future<void> initialize();

  /// Create the remote data source for this provider.
  /// Returns null if the provider cannot create a datasource (e.g., missing config).
  AuthRemoteDataSource? createRemoteDataSource();

  /// Clean up provider resources. Called during forced logout or app teardown.
  Future<void> dispose();
}
