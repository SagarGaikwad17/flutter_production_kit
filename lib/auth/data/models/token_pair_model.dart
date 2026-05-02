import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';

/// Data model for token pair serialization.
///
/// Design rationale:
/// Tokens are stored as JSON in secure storage. The expiry is stored
/// as an ISO 8601 string for timezone safety.
class TokenPairModel {
  const TokenPairModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
    this.scope,
    this.issuedAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final String? scope;
  final DateTime? issuedAt;

  factory TokenPairModel.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expires_at'];
    final expiresAt = expiresAtRaw != null
        ? DateTime.parse(expiresAtRaw.toString())
        : DateTime.now().add(const Duration(hours: 1));

    final issuedAtRaw = json['issued_at'];
    final issuedAt = issuedAtRaw != null
        ? DateTime.tryParse(issuedAtRaw.toString())
        : null;

    return TokenPairModel(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: expiresAt,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scope: json['scope'] as String?,
      issuedAt: issuedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'scope': scope,
      'issued_at': issuedAt?.toIso8601String(),
    };
  }

  TokenPair toDomain() {
    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      tokenType: tokenType,
      scope: scope,
      issuedAt: issuedAt,
    );
  }

  static TokenPairModel fromDomain(TokenPair pair) {
    return TokenPairModel(
      accessToken: pair.accessToken,
      refreshToken: pair.refreshToken,
      expiresAt: pair.expiresAt,
      tokenType: pair.tokenType,
      scope: pair.scope,
      issuedAt: pair.issuedAt,
    );
  }
}
