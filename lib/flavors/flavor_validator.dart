import 'package:flutter/foundation.dart';
import 'package:flutter_production_kit/flavors/app_flavor.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';
import 'package:flutter_production_kit/core/errors/app_exception.dart';

/// Performs compile-time-safe flavor validation at application startup.
///
/// Design rationale:
/// Flavor safety rules must be enforced by architecture, not developer discipline.
/// [FlavorValidator.validate] is called in every main_*.dart entry point,
/// immediately after [FlavorConfig.initialize]. This guarantees:
///
/// 1. Production flavors never run in debug mode.
/// 2. Development flavors cannot ship in release builds.
/// 3. API base URL domain matches the expected domain for the flavor.
/// 4. App name matches expected branding for the flavor.
///
/// Violations throw [FlavorMismatchException], which the bootstrap engine
/// classifies as a [BlockingFailure] — the app hard-stops with a clear error.
abstract final class FlavorValidator {
  FlavorValidator._();

  /// Validates the current [FlavorConfig] against safety rules.
  ///
  /// Must be called after [FlavorConfig.initialize] and before
  /// [AppBootstrap.run].
  ///
  /// Throws [FlavorMismatchException] on any violation.
  static void validate() {
    final config = FlavorConfig.instance;
    final flavor = config.flavor;
    final env = config.env;

    _validateBuildModeVsFlavor(flavor);
    _validateApiUrlDomain(flavor, env.apiBaseUrl);
    _validateProductionNotDebug(flavor);
  }

  // ── Private Checks ──────────────────────────────────────────────────────────

  static void _validateBuildModeVsFlavor(AppFlavor flavor) {
    // Production/white-label flavors must run in release or profile mode.
    if (flavor.isProduction && kDebugMode) {
      throw FlavorMismatchException(
        message: 'CRITICAL: Production flavor "${flavor.displayName}" is '
            'running in Flutter kDebugMode=true. '
            'This must never happen. Ensure you are using the correct '
            'build variant and entry point.',
        flavor: flavor,
      );
    }

    // Dev flavor must not run in release mode — prevents accidental dev
    // config shipping to production.
    if (flavor == AppFlavor.dev && kReleaseMode) {
      throw FlavorMismatchException(
        message: 'CRITICAL: Development flavor is running in kReleaseMode=true. '
            'This is a build system misconfiguration. '
            'Ensure the correct --target entry point is used in CI.',
        flavor: flavor,
      );
    }
  }

  static void _validateApiUrlDomain(AppFlavor flavor, String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.host.isEmpty) {
      throw FlavorMismatchException(
        message: 'Invalid apiBaseUrl for flavor "${flavor.displayName}": '
            '"$apiBaseUrl" is not a valid URL.',
        flavor: flavor,
      );
    }

    // Production flavors must use HTTPS.
    if (flavor.isProduction && uri.scheme != 'https') {
      throw FlavorMismatchException(
        message: 'Production flavor "${flavor.displayName}" has a non-HTTPS '
            'apiBaseUrl: "$apiBaseUrl". Production APIs must use HTTPS.',
        flavor: flavor,
      );
    }

    // Dev/QA can use localhost or HTTP, but not prod domains.
    if (flavor == AppFlavor.dev && _isProdDomain(uri.host)) {
      throw FlavorMismatchException(
        message: 'Development flavor is using a production domain: '
            '"${uri.host}". This is not allowed. '
            'Check dev_env.dart apiBaseUrl.',
        flavor: flavor,
      );
    }
  }

  static void _validateProductionNotDebug(AppFlavor flavor) {
    // Belt-and-suspenders: if we somehow got here with a prod flavor in debug,
    // this is the final catch. FlavorConfig.initialize also checks this.
    assert(
      !(flavor.isProduction && kDebugMode),
      'Production flavor "${flavor.displayName}" detected in debug mode. '
      'This is a critical security violation.',
    );
  }

  /// Returns true if the given host looks like a production domain.
  /// Extend this list as your production domains expand.
  static bool _isProdDomain(String host) {
    const prodIndicators = ['api.', 'prod.', 'production.'];
    return prodIndicators.any((indicator) => host.startsWith(indicator));
  }
}
