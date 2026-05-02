/// Grace policy — determines grace period behavior.
///
/// Design rationale:
/// - Configurable grace period duration.
/// - Configurable restricted period duration.
/// - Determines when to transition from grace → restricted → suspended.
/// - Balances user experience with revenue protection.
class GracePolicy {
  const GracePolicy({
    this.gracePeriodDays = 7,
    this.restrictedPeriodDays = 14,
    this.allowFullAccessDuringGrace = true,
    this.restrictedActions = const [],
    this.suspendAfterRestricted = true,
  });

  /// Days of grace period after payment failure.
  final int gracePeriodDays;

  /// Days of restricted access after grace expires.
  final int restrictedPeriodDays;

  /// User retains full access during grace.
  final bool allowFullAccessDuringGrace;

  /// Actions blocked during restricted access.
  final List<String> restrictedActions;

  /// Suspend subscription after restricted period.
  final bool suspendAfterRestricted;

  /// Get the grace end date from now.
  DateTime getGraceEndDate() {
    return DateTime.now().add(Duration(days: gracePeriodDays));
  }

  /// Get the restricted end date from grace end.
  DateTime getRestrictedEndDate(DateTime graceEndsAt) {
    return graceEndsAt.add(Duration(days: restrictedPeriodDays));
  }
}
