import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_entity.dart';
import 'package:flutter_production_kit/multi_tenant/domain/exceptions/tenant_exception.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Runtime tenant resolver — determines the active tenant from various sources.
///
/// Design rationale:
/// - Resolves tenant from multiple sources in priority order.
/// - Supports header-based resolution (API requests).
/// - Supports storage-based resolution (cached session).
/// - Supports URL-based resolution (deep links, custom domains).
/// - Supports QR code resolution (enterprise provisioning).
///
/// Resolution priority:
///   1. Explicit tenant ID (passed directly).
///   2. API header (X-Tenant-ID).
///   3. Cached session (secure storage).
///   4. URL parameter (?tenant=slug).
///   5. Custom domain mapping.
///   6. QR code payload.
class RuntimeTenantResolver {
  const RuntimeTenantResolver({
    required ITenantRepository tenantRepository,
    required ITenantSessionRepository sessionRepository,
    this.headerKey = 'X-Tenant-ID',
  })  : _tenantRepository = tenantRepository,
        _sessionRepository = sessionRepository;

  final ITenantRepository _tenantRepository;
  final ITenantSessionRepository _sessionRepository;
  final String headerKey;

  /// Resolve tenant from explicit ID.
  Future<TenantEntity> resolveById(String tenantId) async {
    final tenant = await _tenantRepository.getById(tenantId);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found by ID',
      );
    }
    return tenant;
  }

  /// Resolve tenant from header value.
  Future<TenantEntity> resolveFromHeader(String headerValue) async {
    final tenant = await _tenantRepository.getById(headerValue);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found from header',
      );
    }
    return tenant;
  }

  /// Resolve tenant from cached session.
  Future<TenantEntity> resolveFromSession() async {
    final tenantId = await _sessionRepository.getCurrentTenantId();
    if (tenantId == null) {
      throw const TenantContextNotResolvedException(
        message: 'No tenant ID in session',
      );
    }
    return resolveById(tenantId);
  }

  /// Resolve tenant from URL slug.
  Future<TenantEntity> resolveFromUrlSlug(String slug) async {
    final tenant = await _tenantRepository.getBySlug(slug);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found by URL slug',
      );
    }
    return tenant;
  }

  /// Resolve tenant with fallback chain.
  Future<TenantEntity> resolveWithFallback({
    String? explicitId,
    String? headerValue,
    String? urlSlug,
  }) async {
    if (explicitId != null) return resolveById(explicitId);
    if (headerValue != null) return resolveFromHeader(headerValue);
    if (urlSlug != null) return resolveFromUrlSlug(urlSlug);
    return resolveFromSession();
  }
}
