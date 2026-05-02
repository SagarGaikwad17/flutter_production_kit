import 'package:flutter_production_kit/multi_tenant/domain/entities/branding_config.dart';
import 'package:flutter_production_kit/multi_tenant/white_label/branding_engine.dart';

/// Theme runtime manager — applies branding to Flutter theme at runtime.
///
/// Design rationale:
/// - Converts BrandingConfig into Flutter theme data.
/// - Supports dynamic theme updates without restart.
/// - Falls back to defaults if branding fields are missing.
/// - Separates theme concerns from branding data loading.
class ThemeRuntimeManager {
  const ThemeRuntimeManager({
    required BrandingEngine brandingEngine,
  }) : _brandingEngine = brandingEngine;

  final BrandingEngine _brandingEngine;

  /// Get the resolved branding config for a tenant.
  Future<BrandingConfig> getBrandingForTenant(String tenantId) async {
    return _brandingEngine.resolveBranding(tenantId);
  }

  /// Extract primary color from branding config.
  String? getPrimaryColor(BrandingConfig branding) {
    return branding.primaryColor;
  }

  /// Extract secondary color from branding config.
  String? getSecondaryColor(BrandingConfig branding) {
    return branding.secondaryColor;
  }

  /// Extract font family from branding config.
  String? getFontFamily(BrandingConfig branding) {
    return branding.fontFamily;
  }

  /// Get app name from branding config.
  String getAppName(BrandingConfig branding, String fallback) {
    return branding.appName ?? fallback;
  }

  /// Get logo URL from branding config.
  String? getLogoUrl(BrandingConfig branding) {
    return branding.logoUrl;
  }

  /// Check if branding has custom login configuration.
  bool hasCustomLoginConfig(BrandingConfig branding) {
    return branding.loginScreenConfig != null;
  }
}
