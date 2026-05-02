import 'package:flutter_production_kit/auth/domain/entities/token_pair.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';

/// Abstract local auth datasource — secure storage operations.
///
/// Design rationale:
/// All token persistence goes through this interface.
/// Implementations MUST use secure storage (Keychain/Keystore),
/// never SharedPreferences or unencrypted storage.
///
/// Corruption recovery: if stored data is unreadable, implementations
/// should throw [AuthStorageCorruptedException] so the session engine
/// can trigger a clean logout rather than crashing.
abstract class AuthLocalDataSource {
  /// Save the token pair to secure storage.
  Future<void> saveTokens(TokenPair tokens);

  /// Save the refresh token separately (higher security tier).
  Future<void> saveRefreshToken(String refreshToken);

  /// Save the user profile to secure storage.
  Future<void> saveUserProfile(UserProfile profile);

  /// Save the session ID.
  Future<void> saveSessionId(String sessionId);

  /// Save session metadata as JSON string.
  Future<void> saveSessionMetadata(Map<String, dynamic> metadata);

  /// Read the stored access token. Returns null if none exists.
  Future<String?> readAccessToken();

  /// Read the stored refresh token. Returns null if none exists.
  Future<String?> readRefreshToken();

  /// Read the stored user profile. Returns null if none exists.
  Future<UserProfile?> readUserProfile();

  /// Read the stored session ID. Returns null if none exists.
  Future<String?> readSessionId();

  /// Read session metadata. Returns null if none exists.
  Future<Map<String, dynamic>?> readSessionMetadata();

  /// Read the token expiry timestamp. Returns null if none exists.
  Future<DateTime?> readTokenExpiry();

  /// Save the token expiry timestamp.
  Future<void> saveTokenExpiry(DateTime expiry);

  /// Check if any auth data exists in secure storage.
  Future<bool> hasStoredAuth();

  /// Clear ALL auth data from secure storage.
  ///
  /// This is a hard reset — used during forced logout or
  /// storage corruption recovery.
  Future<void> clearAllAuthData();

  /// Clear only the access token (e.g., for forced refresh).
  Future<void> clearAccessToken();
}
