import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';

/// Use case: Restore a previously authenticated session.
///
/// Design rationale:
/// Called during bootstrap. Attempts to rebuild session from secure storage.
/// Returns a clear result — success or explicit failure reason.
class RestoreSessionUseCase {
  RestoreSessionUseCase({required this.repository});

  final AuthRepository repository;

  Future<AuthRestoreResult> execute() {
    return repository.restoreSession();
  }
}
