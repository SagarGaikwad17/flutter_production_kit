import 'package:flutter_production_kit/bootstrap/bootstrap_context.dart';
import 'package:flutter_production_kit/core/errors/app_exception.dart';
import 'package:flutter_production_kit/core/logging/app_logger.dart';
import 'package:flutter_production_kit/flavors/flavor_config.dart';
import 'package:flutter_production_kit/flavors/flavor_validator.dart';

/// Step 1: Validates flavor configuration before any other step runs.
///
/// Failure mode: blocking — nothing can run if the config is invalid.
class FlavorInitStep {
  static const String _tag = 'FlavorInitStep';

  Future<void> execute(BootstrapContext ctx) async {
    AppLogger.info(_tag, 'Validating flavor: ${FlavorConfig.instance.flavor.displayName}');

    try {
      FlavorValidator.validate();
      AppLogger.info(_tag, 'Flavor validation passed.');
    } on FlavorMismatchException catch (e, st) {
      AppLogger.fatal(_tag, 'Flavor validation FAILED — this is a blocking failure.', error: e, stackTrace: st);
      rethrow; // Propagate as blocking
    }
  }
}
