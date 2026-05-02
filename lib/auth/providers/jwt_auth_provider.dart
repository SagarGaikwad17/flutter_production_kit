import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_production_kit/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_production_kit/auth/data/models/token_pair_model.dart';
import 'package:flutter_production_kit/auth/data/models/user_profile_model.dart';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// JWT-based auth remote datasource implementation.
///
/// Design rationale:
/// - Standard REST API auth flow: login → tokens → refresh.
/// - All HTTP errors are mapped to domain exceptions.
/// - Network availability is checked before each request.
/// - Response parsing is lenient — missing optional fields don't crash.
class JwtRemoteDataSource implements AuthRemoteDataSource {
  JwtRemoteDataSource({
    required String baseUrl,
    http.Client? client,
    this.connectivityChecker = const ConnectivityChecker(),
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  static const String _tag = 'JwtRemoteDataSource';

  final String _baseUrl;
  final http.Client _client;
  final ConnectivityChecker connectivityChecker;

  static const Duration _timeout = Duration(seconds: 15);

  @override
  Future<TokenPair> loginWithEmail({
    required String email,
    required String password,
  }) async {
    await _checkConnectivity();

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      throw const InvalidCredentialsException(
        message: 'Invalid email or password.',
      );
    }

    if (response.statusCode == 403) {
      throw GenericAuthException(message: 'Account is disabled or banned.');
    }

    if (response.statusCode >= 500) {
      throw const AuthProviderUnavailableException(
        message: 'Auth server is unavailable.',
        providerType: 'JWT',
      );
    }

    if (response.statusCode != 200) {
      throw GenericAuthException(message: 'Login failed with status: ${response.statusCode}');
    }

    final json = _decodeBody(response);
    AppLogger.info(_tag, 'JWT login successful.');
    return TokenPairModel.fromJson(json).toDomain();
  }

  @override
  Future<TokenPair> loginWithProviderToken({
    required String providerToken,
    required String providerId,
  }) async {
    await _checkConnectivity();

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/oauth'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'provider': providerId,
            'token': providerToken,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      throw const InvalidCredentialsException(
        message: 'OAuth provider token was rejected.',
      );
    }

    if (response.statusCode >= 500) {
      throw const AuthProviderUnavailableException(
        message: 'OAuth endpoint unavailable.',
        providerType: 'JWT',
      );
    }

    final json = _decodeBody(response);
    return TokenPairModel.fromJson(json).toDomain();
  }

  @override
  Future<TokenPair> refreshToken({
    required String refreshToken,
  }) async {
    await _checkConnectivity();

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      final json = _decodeBody(response);
      final error = json['error'] as String? ?? '';
      if (error.contains('expired') || error.contains('invalid')) {
        throw const RefreshTokenExpiredException(
          message: 'Refresh token has expired.',
        );
      }
      throw const InvalidCredentialsException(
        message: 'Refresh token was rejected.',
      );
    }

    if (response.statusCode == 403) {
      throw const SessionRevokedException(
        message: 'Session was revoked by the server.',
      );
    }

    if (response.statusCode >= 500) {
      throw const AuthProviderUnavailableException(
        message: 'Auth server unavailable during refresh.',
        providerType: 'JWT',
      );
    }

    final json = _decodeBody(response);
    AppLogger.info(_tag, 'JWT token refresh successful.');
    return TokenPairModel.fromJson(json).toDomain();
  }

  @override
  Future<SessionValidationResponse> validateSession({
    required String sessionId,
    required String accessToken,
  }) async {
    await _checkConnectivity();

    final response = await _client
        .get(
          Uri.parse('$_baseUrl/auth/session/$sessionId/validate'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SessionRevokedException(
        message: 'Session validation failed — session revoked.',
      );
    }

    if (response.statusCode >= 500) {
      throw const AuthNetworkUnavailableException(
        message: 'Server error during session validation.',
      );
    }

    final json = _decodeBody(response);
    final permissions = json['permissions'] as List<dynamic>?;

    return SessionValidationResponse(
      isValid: json['is_valid'] as bool? ?? false,
      permissions: permissions?.map((e) => e.toString()).toList(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'].toString())
          : null,
      multiDeviceCount: json['active_sessions'] as int?,
    );
  }

  @override
  Future<void> revokeSession({required String sessionId}) async {
    try {
      await _client.delete(
        Uri.parse('$_baseUrl/auth/session/$sessionId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
    } catch (e) {
      AppLogger.warning(_tag, 'Session revocation request failed (non-critical).', error: e);
    }
  }

  @override
  Future<UserProfile> getUserProfile({required String userId}) async {
    await _checkConnectivity();

    final response = await _client
        .get(
          Uri.parse('$_baseUrl/users/$userId'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw GenericAuthException(message: 'Failed to fetch user profile: ${response.statusCode}');
    }

    final json = _decodeBody(response);
    return UserProfileModel.fromJson(json).toDomain();
  }

  @override
  Future<void> logout({required String sessionId}) async {
    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': sessionId}),
          )
          .timeout(_timeout);
    } catch (e) {
      AppLogger.warning(_tag, 'Server logout failed (non-critical — local data will be cleared).', error: e);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _checkConnectivity() async {
    final result = await connectivityChecker.checkConnectivity();
    final hasNetwork = result.isNotEmpty &&
        result.any((c) => c != ConnectivityResult.none);
    if (!hasNetwork) {
      throw const AuthNetworkUnavailableException(
        message: 'No network connection available.',
      );
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final body = response.body;
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw GenericAuthException(
        message: 'Invalid JSON response from auth server.',
        cause: e,
      );
    }
  }
}

/// Abstraction for connectivity checking — allows testing.
class ConnectivityChecker {
  const ConnectivityChecker();

  Future<List<ConnectivityResult>> checkConnectivity() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return [ConnectivityResult.none];
    }
  }
}
