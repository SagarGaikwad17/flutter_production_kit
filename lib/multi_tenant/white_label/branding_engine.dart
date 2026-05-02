import 'package:flutter_production_kit/multi_tenant/domain/entities/branding_config.dart';
import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_access_result.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Branding engine — resolves and applies white-label branding per tenant.
///
/// Design rationale:
/// - Loads tenant-specific branding at runtime.
/// - Merges with default branding for missing fields.
/// - Validates branding isolation (correct tenant branding loaded).
/// - Caches branding to avoid repeated network calls.
///
/// Branding lifecycle:
///   1. resolve() — fetch tenant branding, merge with defaults, cache.
///   2. get() — return cached branding if tenant matches.
///   3. invalidate() — clear cached branding.
///   4. switch — invalidate old, resolve new.
class BrandingEngine {
  BrandingEngine({
    required IBrandingRepository brandingRepository,
    BrandingConfig? defaultBranding,
  })  : _brandingRepository = brandingRepository,
        _defaultBranding = defaultBranding;

  final IBrandingRepository _brandingRepository;
  final BrandingConfig? _defaultBranding;

  String? _cachedTenantId;
  BrandingConfig? _cachedBranding;

  /// Resolve branding for a tenant.
  Future<BrandingConfig> resolveBranding(String tenantId) async {
    if (_cachedTenantId == tenantId && _cachedBranding != null) {
      return _cachedBranding!;
    }

    final configMap = await _brandingRepository.getBrandingConfig(tenantId);
    BrandingConfig branding;

    if (configMap != null && configMap.isNotEmpty) {
      branding = _fromMap(tenantId, configMap);
    } else {
      branding = BrandingConfig(tenantId: tenantId);
    }

    final merged = _defaultBranding != null
        ? branding.mergeWithDefault(_defaultBranding!)
        : branding;

    _cachedTenantId = tenantId;
    _cachedBranding = merged;
    return merged;
  }

  /// Validate branding isolation.
  TenantAccessResult validateBrandingIsolation({
    required String expectedTenantId,
    required String loadedTenantId,
  }) {
    if (expectedTenantId != loadedTenantId) {
      return BrandingIsolationEnforced(tenantId: expectedTenantId, brandingLoaded: false);
    }
    return BrandingIsolationEnforced(tenantId: expectedTenantId, brandingLoaded: true);
  }

  /// Invalidate cached branding.
  void invalidate() {
    _cachedTenantId = null;
    _cachedBranding = null;
  }

  BrandingConfig _fromMap(String tenantId, Map<String, String> map) {
    return BrandingConfig(
      tenantId: tenantId,
      appName: map['appName'],
      logoUrl: map['logoUrl'],
      faviconUrl: map['faviconUrl'],
      primaryColor: map['primaryColor'],
      secondaryColor: map['secondaryColor'],
      backgroundColor: map['backgroundColor'],
      textColor: map['textColor'],
      fontFamily: map['fontFamily'],
      footerText: map['footerText'],
      supportEmail: map['supportEmail'],
      supportPhone: map['supportPhone'],
      termsUrl: map['termsUrl'],
      privacyUrl: map['privacyUrl'],
    );
  }
}
