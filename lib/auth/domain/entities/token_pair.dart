/// Access + refresh token pair with lifecycle metadata.
///
/// Design rationale:
/// Tokens are always handled as a pair — never store one without the other.
/// [expiresAt] is computed at login/refresh time so expiry checks are
/// timezone-safe and don't depend on clock skew interpretation.
class TokenPair {
  const TokenPair({
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

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Returns true if the token expires within the given buffer.
  /// Used for proactive refresh before expiry.
  bool isExpiringWithin(Duration buffer) {
    return DateTime.now().add(buffer).isAfter(expiresAt);
  }

  /// How much time remains before token expiry.
  Duration get timeToExpiry => expiresAt.difference(DateTime.now());

  TokenPair copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? tokenType,
    String? scope,
    DateTime? issuedAt,
  }) {
    return TokenPair(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      tokenType: tokenType ?? this.tokenType,
      scope: scope ?? this.scope,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  @override
  String toString() =>
      'TokenPair(type: $tokenType, expiresAt: $expiresAt, scope: $scope)';
}
