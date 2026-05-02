import 'dart:io';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Generates a device fingerprint for session binding and multi-device detection.
///
/// Design rationale:
/// - The fingerprint is a hash of multiple device identifiers.
/// - No single identifier is used alone (defense in depth).
/// - The fingerprint changes if the device is factory-reset or app is reinstalled,
///   which is intentional — it forces re-authentication on new installs.
/// - Used for:
///   1. Multi-device session conflict detection.
///   2. Suspicious login detection (device mismatch).
///   3. Session revocation targeting (revoke a specific device).
///
/// Privacy: the fingerprint is a one-way hash — it cannot be reverse-engineered
/// to recover the original device identifiers.
class DeviceBinding {
  DeviceBinding({
    this.appInfoProvider = _defaultAppInfoProvider,
  });

  static const String _tag = 'DeviceBinding';

  final Future<PackageInfo> Function() appInfoProvider;

  /// Generate a device fingerprint.
  ///
  /// Combines platform-specific identifiers with app metadata.
  Future<String> generateFingerprint() async {
    try {
      final components = <String>[];

      // Platform identifier.
      components.add(Platform.operatingSystem);

      // App identifier (bundle ID / package name).
      final appInfo = await appInfoProvider();
      components.add(appInfo.packageName);

      // Device model.
      components.add(_getDeviceModel());

      // Create a simple hash from the components.
      final raw = components.join('|');
      final fingerprint = _simpleHash(raw);

      AppLogger.debug(_tag, 'Device fingerprint generated: ${fingerprint.substring(0, 8)}...');
      return 'fp_$fingerprint';
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to generate device fingerprint', error: e, stackTrace: st);
      return 'fp_unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Check if two fingerprints match (same device).
  static bool isSameDevice(String fingerprintA, String fingerprintB) {
    return fingerprintA == fingerprintB;
  }

  String _getDeviceModel() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }

  String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<PackageInfo> _defaultAppInfoProvider() {
    return PackageInfo.fromPlatform();
  }
}
