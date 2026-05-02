import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';

/// Use case: Revoke a specific session.
///
/// Design rationale:
/// Used for multi-device management — user can revoke sessions
/// from other devices while keeping the current one active.
class RevokeSessionUseCase {
  RevokeSessionUseCase({required this.repository});

  final AuthRepository repository;

  Future<void> execute({required String sessionId}) {
    return repository.revokeSession(sessionId: sessionId);
  }
}
