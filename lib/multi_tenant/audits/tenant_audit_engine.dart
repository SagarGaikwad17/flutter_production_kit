/// Tenant audit engine — records tenant-scoped audit events.
///
/// Design rationale:
/// - All audit events are scoped to a tenant ID.
/// - Events are immutable once written.
/// - Supports structured event payloads.
/// - Integrates with observability audit store.
///
/// Audit event types:
/// - Tenant context resolution.
/// - Tenant switch events.
/// - Branch access events.
/// - Branding load events.
/// - Entitlement check events.
/// - Policy evaluation events.
/// - Cross-tenant violation attempts.
class TenantAuditEngine {
  const TenantAuditEngine({
    required void Function(TenantAuditEvent event) onAuditEvent,
  }) : _onAuditEvent = onAuditEvent;

  final void Function(TenantAuditEvent event) _onAuditEvent;

  /// Record a tenant context resolution event.
  void recordContextResolution({
    required String tenantId,
    required String userId,
    required String correlationId,
    String? branchId,
  }) {
    _onAuditEvent(TenantAuditEvent(
      eventType: TenantAuditEventType.contextResolution,
      tenantId: tenantId,
      userId: userId,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: {
        if (branchId != null) 'branch_id': branchId,
      },
    ));
  }

  /// Record a tenant switch event.
  void recordTenantSwitch({
    required String previousTenantId,
    required String newTenantId,
    required String userId,
    required String correlationId,
  }) {
    _onAuditEvent(TenantAuditEvent(
      eventType: TenantAuditEventType.tenantSwitch,
      tenantId: newTenantId,
      userId: userId,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: {
        'previous_tenant_id': previousTenantId,
        'new_tenant_id': newTenantId,
      },
    ));
  }

  /// Record a branch access event.
  void recordBranchAccess({
    required String tenantId,
    required String userId,
    required String branchId,
    required bool granted,
    String? correlationId,
  }) {
    _onAuditEvent(TenantAuditEvent(
      eventType: TenantAuditEventType.branchAccess,
      tenantId: tenantId,
      userId: userId,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: {
        'branch_id': branchId,
        'granted': granted.toString(),
      },
    ));
  }

  /// Record a branding load event.
  void recordBrandingLoad({
    required String tenantId,
    required String userId,
    required bool success,
    String? correlationId,
  }) {
    _onAuditEvent(TenantAuditEvent(
      eventType: TenantAuditEventType.brandingLoad,
      tenantId: tenantId,
      userId: userId,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: {
        'success': success.toString(),
      },
    ));
  }

  /// Record a cross-tenant violation attempt.
  void recordCrossTenantViolation({
    required String userTenantId,
    required String accessedTenantId,
    required String userId,
    required String resourceType,
    String? resourceId,
    String? correlationId,
  }) {
    _onAuditEvent(TenantAuditEvent(
      eventType: TenantAuditEventType.crossTenantViolation,
      tenantId: userTenantId,
      userId: userId,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: {
        'user_tenant_id': userTenantId,
        'accessed_tenant_id': accessedTenantId,
        'resource_type': resourceType,
        if (resourceId != null) 'resource_id': resourceId,
      },
    ));
  }
}

/// Tenant audit event — structured audit record.
class TenantAuditEvent {
  const TenantAuditEvent({
    required this.eventType,
    required this.tenantId,
    required this.userId,
    required this.timestamp,
    this.correlationId,
    this.metadata = const {},
  });

  final TenantAuditEventType eventType;
  final String tenantId;
  final String userId;
  final String? correlationId;
  final DateTime timestamp;
  final Map<String, String> metadata;
}

enum TenantAuditEventType {
  contextResolution,
  tenantSwitch,
  branchAccess,
  brandingLoad,
  entitlementCheck,
  policyEvaluation,
  crossTenantViolation,
}
