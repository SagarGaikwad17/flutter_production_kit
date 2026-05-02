import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';

/// Immutable user profile resolved after successful authentication.
///
/// Design rationale:
/// - All fields are final — the profile is a snapshot from auth restore.
/// - Roles are loaded at login/restore time and cached in session.
/// - [deviceId] enables multi-device conflict detection.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.roles,
    required this.createdAt,
    this.displayName,
    this.phoneNumber,
    this.avatarUrl,
    this.deviceId,
    this.lastLoginAt,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String? avatarUrl;
  final List<UserRole> roles;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? deviceId;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  bool hasRole(UserRole role) => roles.contains(role);

  bool hasAnyRole(List<UserRole> roles) =>
      roles.any((r) => this.roles.contains(r));

  UserRole get highestRole =>
      roles.isEmpty ? UserRole.guest : roles.reduce((a, b) => a.level > b.level ? a : b);

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? avatarUrl,
    List<UserRole>? roles,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? deviceId,
    bool? isEmailVerified,
    bool? isPhoneVerified,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      deviceId: deviceId ?? this.deviceId,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    );
  }

  @override
  String toString() =>
      'UserProfile(id: $id, email: $email, roles: ${roles.map((e) => e.name)})';
}
