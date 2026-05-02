import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';

/// Use case: Logout and revoke session.
///
/// Design rationale:
/// Logout MUST revoke the server-side session, not just clear local state.
/// The session manager handles local cleanup after this returns.
class LogoutUseCase {
  LogoutUseCase({required this.repository});

  final AuthRepository repository;

  Future<AuthLogoutResult> execute({required String sessionId}) {
    return repository.logout(sessionId: sessionId);
  }
}
