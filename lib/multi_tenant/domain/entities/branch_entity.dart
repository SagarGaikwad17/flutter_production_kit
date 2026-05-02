/// Branch entity — represents a sub-organizational unit within a tenant.
///
/// Design rationale:
/// - [id] is a UUID — globally unique within the tenant.
/// - [tenantId] binds the branch to its parent tenant.
/// - [code] is a human-readable branch identifier (e.g., 'MUM-001').
/// - [name] is the display name.
/// - [parentBranchId] enables hierarchical branch structures.
/// - [hierarchyLevel] determines the branch's position in the hierarchy.
/// - [isActive] controls branch availability.
/// - [allowedUserIds] restricts which users can access this branch.
/// - [metadata] carries safe diagnostic data.
///
/// Branch isolation:
/// - Users can only access branches they're assigned to.
/// - Branch managers can access their branch and child branches.
/// - Super admins can access all branches within their tenant.
/// - Cross-tenant branch access is architecturally impossible.
class BranchEntity {
  const BranchEntity({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.hierarchyLevel,
    this.parentBranchId,
    this.description,
    this.region,
    this.isActive = true,
    this.allowedUserIds = const [],
    this.managerUserId,
    this.metadata = const {},
  });

  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String? description;
  final String? region;
  final int hierarchyLevel;
  final String? parentBranchId;
  final bool isActive;
  final List<String> allowedUserIds;
  final String? managerUserId;
  final Map<String, String> metadata;

  bool get isRoot => parentBranchId == null;
  bool get isLeaf => hierarchyLevel == 0;

  bool hasAccessForUser(String userId) {
    return allowedUserIds.isEmpty || allowedUserIds.contains(userId);
  }
}
