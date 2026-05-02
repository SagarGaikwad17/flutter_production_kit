import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';

/// Use case: Login with email and password.
///
/// Design rationale:
/// - Thin orchestrator: delegates to repository, handles logging.
/// - All business logic (rate limiting, suspicious login detection)
///   lives in the repository or provider layer.
class LoginWithEmailUseCase {
  LoginWithEmailUseCase({required this.repository});

  final AuthRepository repository;

  Future<AuthLoginResult> execute({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      return AuthLoginFailure(
        reason: AuthLoginFailureReason.invalidCredentials,
        error: 'Email and password must not be empty.',
      );
    }

    return repository.loginWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
}
