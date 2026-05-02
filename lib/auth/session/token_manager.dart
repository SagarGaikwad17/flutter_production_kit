import 'dart:async';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_production_kit/auth/session/refresh_lock_manager.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Manages the complete access token lifecycle.
///
/// Design rationale:
/// - Proactive refresh: token is refreshed BEFORE it expires (5 min buffer).
/// - Storm protection: uses [RefreshLockManager] to prevent concurrent refreshes.
/// - Get-token-on-demand: [getValidAccessToken] is the primary public API —
///   callers never check expiry themselves. The manager handles everything.
/// - Refresh failure cascades correctly: if refresh fails with expired refresh
///   token, the [onSessionExpired] callback fires for forced logout.
///
/// Usage:
/// ```dart
/// // In an HTTP interceptor:
/// final token = await tokenManager.getValidAccessToken();
/// request.headers['Authorization'] = 'Bearer $token';
/// ```
class TokenManager {
  TokenManager({
    required RefreshLockManager refreshLockManager,
    required AuthRepository authRepository,
    required Function() onSessionExpired,
    this.refreshBuffer = const Duration(minutes: 5),
  })  : _lockManager = refreshLockManager,
        _authRepository = authRepository,
        _onSessionExpired = onSessionExpired;

  static const String _tag = 'TokenManager';

  final RefreshLockManager _lockManager;
  final AuthRepository _authRepository;
  final Function() _onSessionExpired;
  final Duration refreshBuffer;

  TokenPair? _currentTokens;
  String? _storedRefreshToken;
  StreamController<TokenRefreshEvent>? _eventController;

  /// Stream of token lifecycle events for observers (HTTP interceptors, UI).
  Stream<TokenRefreshEvent> get eventStream =>
      (_eventController ??= StreamController<TokenRefreshEvent>.broadcast()).stream;

  /// Set the current token pair after login or restore.
  void setTokens(TokenPair tokens, {String? refreshToken}) {
    _currentTokens = tokens;
    _storedRefreshToken = refreshToken ?? tokens.refreshToken;
    AppLogger.info(_tag, 'Tokens set — expires at: ${tokens.expiresAt}');
  }

  /// Clear tokens (logout or session invalidation).
  void clearTokens() {
    _currentTokens = null;
    _storedRefreshToken = null;
    AppLogger.info(_tag, 'Tokens cleared.');
  }

  /// Get a valid access token, refreshing if necessary.
  ///
  /// This is the PRIMARY entry point for API calls. It handles:
  /// - Token not set → throws [TokenExpiredException]
  /// - Token expired or expiring soon → triggers refresh (with storm protection)
  /// - Token still valid → returns immediately
  ///
  /// Thread-safe: concurrent calls share a single refresh operation.
  Future<String> getValidAccessToken() async {
    final tokens = _currentTokens;
    if (tokens == null) {
      AppLogger.warning(_tag, 'No tokens available — session not established.');
      throw const TokenExpiredException(
        message: 'No access token available. User must authenticate.',
      );
    }

    if (!tokens.isExpired && !tokens.isExpiringWithin(refreshBuffer)) {
      AppLogger.trace(_tag, 'Token still valid — returning immediately.');
      return tokens.accessToken;
    }

    AppLogger.info(_tag, 'Token expiring soon or expired — triggering refresh.');
    return _refreshAndGet();
  }

  /// Check if a proactive refresh should be scheduled.
  ///
  /// Call this on app resume or at regular intervals (e.g., every 10 minutes)
  /// to keep the token fresh without waiting for an API call to trigger it.
  Future<bool> performProactiveRefresh() async {
    final tokens = _currentTokens;
    if (tokens == null || _storedRefreshToken == null) {
      return false;
    }

    if (!tokens.isExpiringWithin(refreshBuffer)) {
      AppLogger.trace(_tag, 'Token not near expiry — skipping proactive refresh.');
      return true;
    }

    AppLogger.info(_tag, 'Proactive refresh triggered.');
    return _refreshTokens();
  }

  /// Force invalidate the current token — next call to [getValidAccessToken]
  /// will trigger a refresh even if the token appears valid.
  void forceInvalidate() {
    if (_currentTokens != null) {
      _currentTokens = _currentTokens!.copyWith(
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
      AppLogger.info(_tag, 'Token force-invalidated — next request will trigger refresh.');
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<String> _refreshAndGet() async {
    final refreshToken = _storedRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      AppLogger.warning(_tag, 'No refresh token available — session expired.');
      _onSessionExpired();
      throw const RefreshTokenExpiredException(
        message: 'No refresh token available. Full re-authentication required.',
      );
    }

    final success = await _lockManager.executeRefresh(
      refreshOperation: () => _refreshTokens(),
    );

    if (!success) {
      AppLogger.error(_tag, 'Token refresh failed — notifying session expired.', error: Exception('Refresh failed'));
      _onSessionExpired();
      throw const RefreshTokenExpiredException(
        message: 'Token refresh failed. Session may have been revoked.',
      );
    }

    final newTokens = _currentTokens;
    if (newTokens == null) {
      throw const TokenExpiredException(
        message: 'Token refresh succeeded but no tokens available — internal error.',
      );
    }

    return newTokens.accessToken;
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = _storedRefreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final result = await _authRepository.refreshTokens(refreshToken: refreshToken);

      return switch (result) {
        AuthRefreshSuccess(:final newTokens) =>
          _applyRefreshedTokens(newTokens),
        AuthRefreshFailure(:final reason, :final error) =>
          _handleRefreshFailure(reason, error),
      };
    } catch (e, st) {
      AppLogger.error(_tag, 'Unexpected error during token refresh', error: e, stackTrace: st);
      return false;
    }
  }

  bool _applyRefreshedTokens(TokenPair newTokens) {
    _currentTokens = newTokens;
    _storedRefreshToken = newTokens.refreshToken;
    _emitEvent(TokenRefreshed(newTokens));
    AppLogger.info(_tag, 'Tokens refreshed successfully — new expiry: ${newTokens.expiresAt}');
    return true;
  }

  bool _handleRefreshFailure(AuthRefreshFailureReason reason, Object? error) {
    return switch (reason) {
      AuthRefreshFailureReason.refreshTokenExpired ||
      AuthRefreshFailureReason.sessionRevoked =>
        _handlePermanentFailure(),
      AuthRefreshFailureReason.networkUnavailable =>
        _handleNetworkFailure(),
      _ => false,
    };
  }

  bool _handlePermanentFailure() {
    AppLogger.warning(_tag, 'Permanent refresh failure — triggering session expiry.');
    _onSessionExpired();
    _emitEvent(const TokenRefreshPermanentlyFailed());
    return false;
  }

  bool _handleNetworkFailure() {
    final tokens = _currentTokens;
    if (tokens != null && !tokens.isExpired) {
      AppLogger.info(_tag, 'Network unavailable during refresh — using existing (still valid) token.');
      _emitEvent(const TokenRefreshNetworkUnavailable(usedExisting: true));
      return true;
    }

    AppLogger.warning(_tag, 'Network unavailable and token expired — session cannot be refreshed.');
    _onSessionExpired();
    _emitEvent(const TokenRefreshNetworkUnavailable(usedExisting: false));
    return false;
  }

  void _emitEvent(TokenRefreshEvent event) {
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.add(event);
    }
  }

  void dispose() {
    _eventController?.close();
    _eventController = null;
  }
}

// ── Token Lifecycle Events ───────────────────────────────────────────────────

sealed class TokenRefreshEvent {
  const TokenRefreshEvent();
}

final class TokenRefreshed extends TokenRefreshEvent {
  const TokenRefreshed(this.newTokens);
  final TokenPair newTokens;
}

final class TokenRefreshPermanentlyFailed extends TokenRefreshEvent {
  const TokenRefreshPermanentlyFailed();
}

final class TokenRefreshNetworkUnavailable extends TokenRefreshEvent {
  const TokenRefreshNetworkUnavailable({required this.usedExisting});
  final bool usedExisting;
}
