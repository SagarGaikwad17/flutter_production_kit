import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Step 8: Preloads current permission states.
///
/// Failure mode: recoverable.
///
/// Design rationale:
/// We do NOT request permissions here — that must be done contextually in the UI.
/// We only read the current permission status so that the app knows whether
/// to show permission prompts later (e.g., push notification setup screen).
///
/// This step is a placeholder for `permission_handler` integration.
/// Add `permission_handler: ^11.x` to pubspec and implement status checks.
class PermissionPreloadStep {
  static const String _tag = 'PermissionPreloadStep';

  Future<void> execute(BootstrapContext ctx) async {
    AppLogger.info(_tag, 'Preloading permission states...');

    try {
      // TODO(Phase2): Use permission_handler to preload:
      // - Permission.notification.status
      // - Permission.location.status
      // - Permission.camera.status
      // Store results in ctx for use by onboarding/settings flows.

      AppLogger.info(_tag, 'Permission states preloaded (stub).');
    } catch (e, st) {
      AppLogger.warning(_tag, 'Permission preload failed.', error: e, stackTrace: st);
      // Recoverable — permissions will be checked on-demand.
    }
  }
}
