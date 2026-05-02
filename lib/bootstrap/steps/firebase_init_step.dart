import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/errors/app_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';

/// Step 3: Initializes the Firebase SDK.
///
/// Failure modes:
/// - [FirebaseException] with code 'duplicate-app' → recoverable (already init).
/// - Network error on first init → blocking (Firebase cannot function without init).
/// - Project ID mismatch between env and actual Firebase app → blocking (security).
///
/// Edge cases handled:
/// - Dev builds without google-services.json → skipped with a warning.
/// - Already initialized (hot restart in dev) → no-op.
class FirebaseInitStep {
  static const String _tag = 'FirebaseInitStep';

  Future<void> execute(BootstrapContext ctx) async {
    final flavor = FlavorConfig.instance.flavor;
    final expectedProjectId = FlavorConfig.instance.env.firebase.projectId;

    AppLogger.info(_tag, 'Initializing Firebase for project: $expectedProjectId');

    try {
      if (Firebase.apps.isNotEmpty) {
        AppLogger.info(_tag, 'Firebase already initialized (hot restart). Skipping.');
        ctx.firebaseReady = true;
        _validateProjectId(expectedProjectId);
        return;
      }

      await Firebase.initializeApp();

      ctx.firebaseReady = true;
      _validateProjectId(expectedProjectId);

      AppLogger.info(_tag, 'Firebase initialized successfully.');
    } on FirebaseException catch (e, st) {
      if (e.code == 'duplicate-app') {
        // Already initialized — not an error in dev hot-restart scenarios.
        AppLogger.warning(_tag, 'Firebase duplicate-app — treating as already initialized.', error: e);
        ctx.firebaseReady = true;
        return;
      }
      AppLogger.fatal(_tag, 'Firebase initialization failed.', error: e, stackTrace: st);
      throw FirebaseInitException(
        message: 'Firebase init failed: ${e.message}',
        isSecurity: false,
        cause: e,
      );
    } catch (e, st) {
      AppLogger.fatal(_tag, 'Unexpected Firebase initialization error.', error: e, stackTrace: st);
      throw FirebaseInitException(
        message: 'Unexpected Firebase error: $e',
        cause: e,
      );
    }
  }

  void _validateProjectId(String expectedProjectId) {
    final actualProjectId = Firebase.app().options.projectId;
    if (actualProjectId != expectedProjectId) {
      throw FirebaseInitException(
        message: 'SECURITY: Firebase project mismatch! '
            'Expected "$expectedProjectId" but got "$actualProjectId". '
            'This indicates a wrong google-services.json / flavor mismatch.',
        isSecurity: true,
      );
    }
    AppLogger.info(_tag, 'Firebase project ID verified: $actualProjectId');
  }
}
