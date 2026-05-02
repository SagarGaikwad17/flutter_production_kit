import 'package:flutter_production_kit/multi_tenant/domain/entities/tenant_context.dart';
import 'package:flutter_production_kit/multi_tenant/domain/exceptions/tenant_exception.dart';
import 'package:flutter_production_kit/multi_tenant/domain/repositories/tenant_repositories.dart';

/// Tenant context manager — manages the current tenant context lifecycle.
///
/// Design rationale:
/// - Holds the current TenantContext in memory.
/// - Validates context before returning.
/// - Invalidates context on tenant switch.
/// - Correlation ID propagation for observability.
///
/// Context lifecycle:
///   1. resolve() — fetch tenant, build context, cache.
///   2. get() — return cached context if valid.
///   3. switchTenant() — invalidate old, resolve new.
///   4. invalidate() — clear cached context.
class TenantContextManager {
  TenantContextManager({
    required ITenantRepository tenantRepository,
    required ITenantSessionRepository sessionRepository,
  })  : _tenantRepository = tenantRepository,
        _sessionRepository = sessionRepository;

  final ITenantRepository _tenantRepository;
  final ITenantSessionRepository _sessionRepository;

  TenantContext? _currentContext;

  /// Get the current tenant context. Throws if not resolved or invalid.
  TenantContext get currentContext {
    final context = _currentContext;
    if (context == null) {
      throw const TenantContextNotResolvedException(
        message: 'No tenant context resolved. Call resolve() first.',
      );
    }
    if (!context.isValid) {
      throw const TenantContextExpiredException(
        message: 'Tenant context has expired. Call resolve() to refresh.',
      );
    }
    return context;
  }

  /// Check if a valid context exists.
  bool get hasContext {
    final context = _currentContext;
    return context != null && context.isValid;
  }

  /// Resolve tenant context for a user.
  Future<TenantContext> resolve({
    required String userId,
    String? tenantId,
    String? correlationId,
    Duration? ttl,
  }) async {
    final resolvedTenantId =
        tenantId ?? await _sessionRepository.getCurrentTenantId();
    if (resolvedTenantId == null) {
      throw const TenantNotFoundException(
        message: 'No tenant ID available for resolution',
      );
    }

    final tenant = await _tenantRepository.getById(resolvedTenantId);
    if (tenant == null) {
      throw const TenantNotFoundException(
        message: 'Tenant not found during context resolution',
      );
    }
    if (tenant.isSuspended) {
      throw const TenantNotFoundException(
        message: 'Tenant is suspended',
      );
    }
    if (tenant.isExpired) {
      throw const TenantNotFoundException(
        message: 'Tenant has expired',
      );
    }

    final now = DateTime.now();
    final newContext = TenantContext(
      tenant: tenant,
      userId: userId,
      resolvedAt: now,
      correlationId: correlationId ?? _generateCorrelationId(),
      validUntil: ttl != null ? now.add(ttl) : null,
    );

    _currentContext = newContext;
    await _sessionRepository.setCurrentTenantId(resolvedTenantId);
    return newContext;
  }

  /// Switch to a different tenant context.
  Future<TenantContext> switchTenant({
    required String userId,
    required String newTenantId,
    String? correlationId,
  }) async {
    final oldContext = _currentContext;
    final oldTenantId = oldContext?.tenant.id;

    if (oldTenantId != null && oldTenantId == newTenantId) {
      return currentContext;
    }

    _currentContext?.invalidate();

    return resolve(
      userId: userId,
      tenantId: newTenantId,
      correlationId: correlationId,
    );
  }

  /// Invalidate the current context.
  void invalidate() {
    _currentContext = null;
  }

  String _generateCorrelationId() {
    return 'corr_${DateTime.now().millisecondsSinceEpoch}';
  }
}
