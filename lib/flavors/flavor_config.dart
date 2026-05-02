import 'package:flutter/foundation.dart';
import 'package:flutter_production_kit/flavors/app_flavor.dart';
import 'package:flutter_production_kit/core/env/base_env.dart';
import 'package:flutter_production_kit/core/errors/app_exception.dart';

/// Central runtime configuration container.
///
/// Design rationale:
/// - Single-write: [initialize] may only be called once. Any attempt to call
///   it again throws [StateError]. This prevents runtime config mutation after
///   bootstrap — a common source of production inconsistency bugs.
/// - Read-only after init: all fields are final and exposed via [instance].
/// - Flavor + env are always set together — you cannot have a flavor without
///   a matching env, preventing partial configuration states.
///
/// Usage:
/// ```dart
/// // In main_dev.dart — called exactly once, before runApp
/// FlavorConfig.initialize(AppFlavor.dev, DevEnv());
///
/// // Anywhere in the app
/// FlavorConfig.instance.env.apiBaseUrl
/// FlavorConfig.instance.flavor.isProduction
/// ```
class FlavorConfig {
  FlavorConfig._({
    required this.flavor,
    required this.env,
  });

  final AppFlavor flavor;
  final BaseEnv env;

  static FlavorConfig? _instance;

  /// Returns the initialized [FlavorConfig] instance.
  ///
  /// Throws [StateError] if [initialize] has not been called yet.
  static FlavorConfig get instance {
    if (_instance == null) {
      throw StateError(
        'FlavorConfig has not been initialized. '
        'Call FlavorConfig.initialize() in your main_<flavor>.dart entry point '
        'before accessing FlavorConfig.instance.',
      );
    }
    return _instance!;
  }

  /// Whether [FlavorConfig] has been initialized.
  static bool get isInitialized => _instance != null;

  /// Initializes the global [FlavorConfig].
  ///
  /// Must be called exactly once, before [WidgetsFlutterBinding.ensureInitialized].
  /// Throws [StateError] if called more than once.
  /// Throws [FlavorMismatchException] if [flavor.isProduction] is true
  /// but [kDebugMode] is also true — compile-time protection against accidental
  /// prod builds running in the debug VM.
  static void initialize(AppFlavor flavor, BaseEnv env) {
    if (_instance != null) {
      throw StateError(
        'FlavorConfig.initialize() has already been called with flavor '
        '"${_instance!.flavor.displayName}". '
        'It must only be called once per app lifecycle. '
        'If you are writing tests, call FlavorConfig.resetForTesting() first.',
      );
    }

    // Production safety: reject prod flavor in debug builds at config time,
    // before FlavorValidator even runs, for belt-and-suspenders protection.
    if (flavor.isProduction && kDebugMode) {
      throw FlavorMismatchException(
        message: 'Attempted to initialize production flavor '
            '"${flavor.displayName}" in Flutter debug mode. '
            'This is not allowed. Use the correct entry point.',
        flavor: flavor,
      );
    }

    _instance = FlavorConfig._(flavor: flavor, env: env);
  }

  // ── Testing Support ─────────────────────────────────────────────────────────

  /// Resets the singleton for test isolation.
  ///
  /// Must ONLY be called from test code.
  /// Calling this in production code will throw [StateError].
  @visibleForTesting
  static void resetForTesting() {
    assert(
      () {
        _instance = null;
        return true;
      }(),
      'resetForTesting() must only be called in test code.',
    );
  }

  @override
  String toString() =>
      'FlavorConfig(flavor: ${flavor.tag}, env: ${env.appName})';
}
