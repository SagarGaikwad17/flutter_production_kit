/// Represents a user role with permission-aware granularity.
///
/// Design rationale:
/// Roles are the foundation for route guards, service guards, and
/// feature-level access control. The integer [level] allows hierarchical
/// comparison (higher = more privileges).
///
/// ADDING A NEW ROLE:
/// 1. Add enum value here with a unique level.
/// 2. Update any route guards that check specific roles.
/// 3. Update permission preload logic in the session engine.
enum UserRole {
  banned(level: -1),
  guest(level: 0),
  user(level: 10),
  moderator(level: 50),
  admin(level: 100),
  superAdmin(level: 999);

  const UserRole({required this.level});

  final int level;

  bool canAccess(UserRole required) => level >= required.level;
}
