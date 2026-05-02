import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/errors/app_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Step 9: Checks whether a forced app update is required.
///
/// Blocking if [ForcedUpdateException] is thrown. Network errors are recoverable.
class ForcedUpdateCheckStep {
  static const String _tag = 'ForcedUpdateCheckStep';

  Future<void> execute(BootstrapContext ctx) async {
    AppLogger.info(_tag, 'Checking forced update requirement...');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final remoteConfig = ctx.remoteConfigValues;
      final minimumVersion = remoteConfig != null
          ? (remoteConfig['minimum_required_version'] as String? ??
              FlavorConfig.instance.env.featureFlagDefaults.minimumRequiredVersion)
          : FlavorConfig.instance.env.featureFlagDefaults.minimumRequiredVersion;

      AppLogger.info(_tag, 'Current: $currentVersion | Minimum: $minimumVersion');

      if (_isUpdateRequired(currentVersion, minimumVersion)) {
        throw ForcedUpdateException(
          message: 'App version ($currentVersion) below minimum ($minimumVersion).',
          minimumRequiredVersion: minimumVersion,
          currentVersion: currentVersion,
        );
      }
      AppLogger.info(_tag, 'Version check passed.');
    } on ForcedUpdateException {
      rethrow;
    } catch (e, st) {
      AppLogger.warning(_tag, 'Version check failed — skipping.', error: e, stackTrace: st);
    }
  }

  bool _isUpdateRequired(String current, String minimum) {
    try {
      final cur = _parse(current);
      final min = _parse(minimum);
      for (int i = 0; i < 3; i++) {
        if (cur[i] < min[i]) return true;
        if (cur[i] > min[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts;
  }
}
