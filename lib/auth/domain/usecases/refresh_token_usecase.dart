import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';

/// Use case: Refresh access tokens.
///
/// Design rationale:
/// The refresh lock manager ensures only ONE refresh happens at a time.
/// This use case is called by the token manager, not directly by UI code.
class RefreshTokenUseCase {
  RefreshTokenUseCase({required this.repository});

  final AuthRepository repository;

  Future<AuthRefreshResult> execute({required String refreshToken}) {
    return repository.refreshTokens(refreshToken: refreshToken);
  }
}
