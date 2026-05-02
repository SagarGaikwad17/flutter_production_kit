import 'package:flutter_production_kit/flavors/app_flavor.dart';

/// Sealed exception hierarchy for the Flutter Production Kit.
///
/// Design rationale:
/// Using a sealed class hierarchy (instead of bare Exception or String throws)
/// means every catch site can switch-exhaustively over exception types.
/// This prevents silent swallowing of unexpected errors.

sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? '\nCaused by: $cause' : ''}';
}

/// Thrown when the flavor configuration is invalid or contradictory.
///
/// Classified as a blocking bootstrap failure — the app cannot safely start.
final class FlavorMismatchException extends AppException {
  const FlavorMismatchException({
    required super.message,
    required this.flavor,
    super.cause,
  });

  final AppFlavor flavor;
}

/// Thrown when the bootstrap engine encounters a blocking failure.
final class BootstrapException extends AppException {
  const BootstrapException({
    required super.message,
    required this.step,
    this.isBlocking = false,
    super.cause,
  });

  final String step;
  final bool isBlocking;
}

/// Thrown when a required service is accessed before it is initialized.
final class ServiceNotInitializedException extends AppException {
  const ServiceNotInitializedException({
    required super.message,
    required this.serviceName,
    super.cause,
  });

  final String serviceName;
}

/// Thrown when the app detects it is in a maintenance window.
final class MaintenanceModeException extends AppException {
  const MaintenanceModeException({
    required super.message,
    this.maintenanceEndTime,
    super.cause,
  });

  /// If known, the time when maintenance is expected to end.
  final DateTime? maintenanceEndTime;
}

/// Thrown when the current app version is below the minimum required version.
final class ForcedUpdateException extends AppException {
  const ForcedUpdateException({
    required super.message,
    required this.minimumRequiredVersion,
    required this.currentVersion,
    super.cause,
  });

  final String minimumRequiredVersion;
  final String currentVersion;
}

/// Thrown when a network operation fails during bootstrap.
final class NetworkUnavailableException extends AppException {
  const NetworkUnavailableException({
    required super.message,
    super.cause,
  });
}

/// Thrown when Firebase initialization fails.
final class FirebaseInitException extends AppException {
  const FirebaseInitException({
    required super.message,
    this.isSecurity = false,
    super.cause,
  });

  /// True if the failure is a security-related Firebase error (blocking).
  final bool isSecurity;
}
