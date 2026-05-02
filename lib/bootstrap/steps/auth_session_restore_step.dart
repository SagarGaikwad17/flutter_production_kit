import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';

/// Step 7: Restores the existing Firebase Auth session (if any).
///
/// Failure mode: recoverable — treat as logged out.
/// We do NOT show an error screen for auth restore failure; we simply
/// route the user to the login screen.
///
/// Edge cases handled:
/// - Token expired → treat as logged out (auth refresh on next API call).
/// - Firebase not ready → skip (ctx.isAuthenticated stays false).
/// - Auth listener race — we use currentUser snapshot, not a stream listener,
///   to avoid timing issues during bootstrap.
class AuthSessionRestoreStep {
  static const String _tag = 'AuthSessionRestoreStep';

  Future<void> execute(BootstrapContext ctx) async {
    if (!ctx.firebaseReady) {
      AppLogger.warning(_tag, 'Firebase not ready — treating as not authenticated.');
      ctx.isAuthenticated = false;
      return;
    }

    try {
      AppLogger.info(_tag, 'Checking existing auth session...');

      // Reload user to check if the token is still valid.
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        AppLogger.info(_tag, 'No existing auth session found.');
        ctx.isAuthenticated = false;
        return;
      }

      // Force token refresh to catch expired sessions early.
      await user.getIdToken(true);

      ctx.isAuthenticated = true;
      AppLogger.info(_tag, 'Auth session restored for user: ${user.uid}');
    } catch (e, st) {
      // Recoverable — user goes to login.
      AppLogger.warning(
        _tag,
        'Auth session restore failed — treating as not authenticated.',
        error: e,
        stackTrace: st,
      );
      ctx.isAuthenticated = false;
    }
  }
}
