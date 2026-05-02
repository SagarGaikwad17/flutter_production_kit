import 'package:flutter/material.dart';
import 'package:flutter_production_kit/permissions/domain/entities/authorization_result.dart';
import 'package:flutter_production_kit/permissions/engine/permission_engine.dart';

/// Widget that gates its child based on a permission check.
///
/// Design rationale:
/// - Provides a declarative way to hide/show UI based on permissions.
/// - Shows [deniedWidget] when access is denied (default: empty SizedBox).
/// - Shows [loadingWidget] while checking (default: CircularProgressIndicator).
/// - The [onDenied] callback allows analytics/logging of denied access.
/// - NOT a security layer — service-level guards enforce real security.
///   This is a UX layer to prevent users from seeing buttons they can't use.
///
/// Usage:
/// ```dart
/// PermissionGate(
///   engine: permissionEngine,
///   userId: 'user_123',
///   action: 'delete',
///   resource: 'patient',
///   child: ElevatedButton(
///     onPressed: _handleDelete,
///     child: const Text('Delete Patient'),
///   ),
///   deniedWidget: const Text('No permission'),
/// )
/// ```
class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.engine,
    required this.userId,
    required this.action,
    required this.resource,
    required this.child,
    this.deniedWidget,
    this.loadingWidget,
    this.onDenied,
    this.resourceId,
    this.resourceOwnerId,
    this.requiredEntitlements,
    this.isOnline = true,
  });

  final PermissionEngine engine;
  final String userId;
  final String action;
  final String resource;
  final String? resourceId;
  final String? resourceOwnerId;
  final List<String>? requiredEntitlements;
  final bool isOnline;
  final Widget child;
  final Widget? deniedWidget;
  final Widget? loadingWidget;
  final void Function(AuthorizationResult result)? onDenied;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _isChecking = true;
  bool _isAllowed = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void didUpdateWidget(PermissionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId ||
        widget.action != oldWidget.action ||
        widget.resource != oldWidget.resource ||
        widget.resourceId != oldWidget.resourceId ||
        widget.isOnline != oldWidget.isOnline) {
      _checkPermission();
    }
  }

  void _checkPermission() {
    setState(() => _isChecking = true);

    final result = widget.engine.check(
      userId: widget.userId,
      action: widget.action,
      resource: widget.resource,
      resourceId: widget.resourceId,
      resourceOwnerId: widget.resourceOwnerId,
      requiredEntitlements: widget.requiredEntitlements,
      isOnline: widget.isOnline,
    );

    if (mounted) {
      setState(() {
        _isChecking = false;
        _isAllowed = result.isAllowed;
      });

      if (!result.isAllowed && widget.onDenied != null) {
        widget.onDenied!(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return widget.loadingWidget ?? const SizedBox.shrink();
    }

    if (!_isAllowed) {
      return widget.deniedWidget ?? const SizedBox.shrink();
    }

    return widget.child;
  }
}

/// Widget that rebuilds based on permission state changes.
///
/// Design rationale:
/// - Provides the full [AuthorizationResult] to the builder, allowing
///   rich UI responses (different messages for different denial reasons).
/// - Rebuilds automatically when the permission engine state changes.
/// - Useful for showing contextual denial messages:
///   - "Upgrade to premium" for entitlement denials
///   - "Contact admin" for role denials
///   - "Reconnect to internet" for offline denials
///
/// Usage:
/// ```dart
/// PermissionBuilder(
///   engine: permissionEngine,
///   userId: 'user_123',
///   action: 'export',
///   resource: 'report',
///   builder: (context, result) {
///     if (result.isAllowed) {
///       return ElevatedButton(onPressed: _export, child: Text('Export'));
///     }
///     return Text(_getDenialMessage(result));
///   },
/// )
/// ```
class PermissionBuilder extends StatefulWidget {
  const PermissionBuilder({
    super.key,
    required this.engine,
    required this.userId,
    required this.action,
    required this.resource,
    required this.builder,
    this.resourceId,
    this.resourceOwnerId,
    this.requiredEntitlements,
    this.isOnline = true,
  });

  final PermissionEngine engine;
  final String userId;
  final String action;
  final String resource;
  final String? resourceId;
  final String? resourceOwnerId;
  final List<String>? requiredEntitlements;
  final bool isOnline;
  final Widget Function(BuildContext context, AuthorizationResult result) builder;

  @override
  State<PermissionBuilder> createState() => _PermissionBuilderState();
}

class _PermissionBuilderState extends State<PermissionBuilder> {
  late AuthorizationResult _result;

  @override
  void initState() {
    super.initState();
    _result = _evaluate();
  }

  @override
  void didUpdateWidget(PermissionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId ||
        widget.action != oldWidget.action ||
        widget.resource != oldWidget.resource ||
        widget.resourceId != oldWidget.resourceId ||
        widget.isOnline != oldWidget.isOnline) {
      setState(() => _result = _evaluate());
    }
  }

  AuthorizationResult _evaluate() {
    return widget.engine.check(
      userId: widget.userId,
      action: widget.action,
      resource: widget.resource,
      resourceId: widget.resourceId,
      resourceOwnerId: widget.resourceOwnerId,
      requiredEntitlements: widget.requiredEntitlements,
      isOnline: widget.isOnline,
    );
  }

  /// Re-evaluate the permission check — call after engine state changes.
  void refresh() {
    setState(() => _result = _evaluate());
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _result);
  }
}

/// Helper mixin for extracting human-readable denial messages from results.
mixin PermissionMessageMixin {
  /// Get a user-friendly message for a denial result.
  String getDenialMessage(AuthorizationResult result) {
    return switch (result) {
      AuthorizationDenied(:final reason) => reason,
      AuthorizationDeniedExpired(:final reason) =>
        '$reason Please request access again.',
      AuthorizationDeniedEntitlementMissing(:final reason) =>
        '$reason Upgrade your plan to access this feature.',
      AuthorizationDeniedBranchMismatch(:final reason) =>
        '$reason Contact your admin for cross-branch access.',
      AuthorizationDeniedStalePermission(:final reason) =>
        '$reason Please reconnect to refresh permissions.',
      AuthorizationDeniedOffline(:final reason) =>
        '$reason Reconnect to the internet and try again.',
      AuthorizationDeniedOwnership(:final reason) =>
        '$reason Only the owner can perform this action.',
      AuthorizationDeniedTenantMismatch(:final reason) =>
        '$reason Access is restricted to your organization.',
      AuthorizationDeniedRoleConflict(:final reason) =>
        '$reason Contact your admin to resolve the conflict.',
      AuthorizationAllowed() => 'Access granted.',
    };
  }
}
