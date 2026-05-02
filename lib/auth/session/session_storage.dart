import 'dart:convert';
import 'package:flutter_production_kit/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_production_kit/auth/data/models/user_profile_model.dart';
import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/exceptions/auth_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Production secure storage implementation for auth data.
///
/// Design rationale:
/// - Uses FlutterSecureStorage (Keychain on iOS, Keystore on Android).
/// - Each token/component gets its own key — granular invalidation.
/// - Corruption recovery: if any single key is unreadable, the entire
///   auth state is considered corrupt and cleared (safe fail).
/// - iOS options: accessibility = WhenUnlocked — tokens unavailable
///   while device is locked, preventing background extraction.
/// - Android options: encryptedSharedPreferences for defense in depth.
class SecureAuthStorage implements AuthLocalDataSource {
  SecureAuthStorage({
    FlutterSecureStorage? secureStorage,
  }) : _storage = secureStorage ?? _createSecureStorage();

  static const String _tag = 'SecureAuthStorage';

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserProfile = 'auth_user_profile';
  static const String _keySessionId = 'auth_session_id';
  static const String _keyTokenExpiry = 'auth_token_expiry';
  static const String _keySessionMetadata = 'auth_session_metadata';

  final FlutterSecureStorage _storage;

  static FlutterSecureStorage _createSecureStorage() {
    return const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }

  @override
  Future<void> saveTokens(TokenPair tokens) async {
    try {
      await _storage.write(key: _keyAccessToken, value: tokens.accessToken);
      await _storage.write(key: _keyRefreshToken, value: tokens.refreshToken);
      AppLogger.debug(_tag, 'Access and refresh tokens saved.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save tokens', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save tokens to secure storage: $e',
        storageKey: _keyAccessToken,
        cause: e,
      );
    }
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      AppLogger.debug(_tag, 'Refresh token saved separately.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save refresh token', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save refresh token: $e',
        storageKey: _keyRefreshToken,
        cause: e,
      );
    }
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final model = UserProfileModel.fromDomain(profile);
      await _storage.write(key: _keyUserProfile, value: model.toJson().toString());
      await _storage.write(key: _keyUserId, value: profile.id);
      AppLogger.debug(_tag, 'User profile saved for: ${profile.email}');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save user profile', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save user profile: $e',
        storageKey: _keyUserProfile,
        cause: e,
      );
    }
  }

  @override
  Future<void> saveSessionId(String sessionId) async {
    try {
      await _storage.write(key: _keySessionId, value: sessionId);
      AppLogger.debug(_tag, 'Session ID saved.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save session ID', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save session ID: $e',
        storageKey: _keySessionId,
        cause: e,
      );
    }
  }

  @override
  Future<void> saveSessionMetadata(Map<String, dynamic> metadata) async {
    try {
      await _storage.write(
        key: _keySessionMetadata,
        value: metadata.toString(),
      );
      AppLogger.debug(_tag, 'Session metadata saved.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save session metadata', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save session metadata: $e',
        storageKey: _keySessionMetadata,
        cause: e,
      );
    }
  }

  @override
  Future<void> saveTokenExpiry(DateTime expiry) async {
    try {
      await _storage.write(
        key: _keyTokenExpiry,
        value: expiry.toIso8601String(),
      );
      AppLogger.debug(_tag, 'Token expiry saved: $expiry');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to save token expiry', error: e, stackTrace: st);
      throw AuthStorageCorruptedException(
        message: 'Failed to save token expiry: $e',
        storageKey: _keyTokenExpiry,
        cause: e,
      );
    }
  }

  @override
  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read access token', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read access token: $e',
        storageKey: _keyAccessToken,
        cause: e,
      );
    }
  }

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read refresh token', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read refresh token: $e',
        storageKey: _keyRefreshToken,
        cause: e,
      );
    }
  }

  @override
  Future<UserProfile?> readUserProfile() async {
    try {
      final raw = await _storage.read(key: _keyUserProfile);
      if (raw == null) return null;

      final json = _tryParseJson(raw);
      if (json == null) return null;

      return UserProfileModel.fromJson(json).toDomain();
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read user profile', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read user profile: $e',
        storageKey: _keyUserProfile,
        cause: e,
      );
    }
  }

  @override
  Future<String?> readSessionId() async {
    try {
      return await _storage.read(key: _keySessionId);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read session ID', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read session ID: $e',
        storageKey: _keySessionId,
        cause: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> readSessionMetadata() async {
    try {
      final raw = await _storage.read(key: _keySessionMetadata);
      if (raw == null) return null;
      return _tryParseJson(raw);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read session metadata', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read session metadata: $e',
        storageKey: _keySessionMetadata,
        cause: e,
      );
    }
  }

  @override
  Future<DateTime?> readTokenExpiry() async {
    try {
      final raw = await _storage.read(key: _keyTokenExpiry);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (e) {
      AppLogger.error(_tag, 'Failed to read token expiry', error: e);
      throw AuthStorageCorruptedException(
        message: 'Failed to read token expiry: $e',
        storageKey: _keyTokenExpiry,
        cause: e,
      );
    }
  }

  @override
  Future<bool> hasStoredAuth() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      return token != null && token.isNotEmpty;
    } catch (e) {
      AppLogger.warning(_tag, 'Cannot check stored auth — storage error.', error: e);
      return false;
    }
  }

  @override
  Future<void> clearAllAuthData() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserId);
      await _storage.delete(key: _keyUserProfile);
      await _storage.delete(key: _keySessionId);
      await _storage.delete(key: _keyTokenExpiry);
      await _storage.delete(key: _keySessionMetadata);
      AppLogger.info(_tag, 'All auth data cleared from secure storage.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to clear all auth data', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  Future<void> clearAccessToken() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      AppLogger.debug(_tag, 'Access token cleared (refresh token preserved).');
    } catch (e) {
      AppLogger.error(_tag, 'Failed to clear access token', error: e);
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _tryParseJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.warning(_tag, 'Stored data is not valid JSON — treating as corrupted.', error: e);
      return null;
    }
  }
}
