import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Step 2: Initializes flutter_secure_storage and verifies read/write access.
///
/// Failure mode: blocking — if secure storage is inaccessible, auth restore
/// (step 7) cannot work and we risk security-unsafe fallback behavior.
///
/// Edge cases handled:
/// - Device has no secure enclave (old Android without keystore) → blocking.
/// - Storage is locked (biometric required but not presented) → blocking.
class SecureStorageInitStep {
  static const String _tag = 'SecureStorageInitStep';

  final FlutterSecureStorage _storage;

  SecureStorageInitStep()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  Future<void> execute(BootstrapContext ctx) async {
    AppLogger.info(_tag, 'Initializing secure storage...');

    try {
      // Verify read/write works — some devices silently fail without error.
      const testKey = '__bootstrap_test__';
      await _storage.write(key: testKey, value: '1');
      final val = await _storage.read(key: testKey);
      await _storage.delete(key: testKey);

      if (val != '1') {
        throw StateError('Secure storage read/write verification failed.');
      }

      ctx.secureStorageReady = true;
      AppLogger.info(_tag, 'Secure storage initialized and verified.');
    } catch (e, st) {
      AppLogger.error(_tag, 'Secure storage initialization failed.', error: e, stackTrace: st);
      rethrow;
    }
  }
}
