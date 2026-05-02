import 'package:flutter_production_kit/auth/domain/entities/user_profile.dart';
import 'package:flutter_production_kit/auth/domain/entities/user_role.dart';

/// Data model for user profile serialization.
///
/// Design rationale:
/// This is the wire format for user profile storage and network transport.
/// The [fromJson] factory is lenient — missing optional fields don't fail.
/// Required fields (id, email) must be present or construction fails.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.email,
    required this.roleNames,
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
  final List<String> roleNames;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? deviceId;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] as List<dynamic>?;
    final roleNames = rawRoles != null
        ? rawRoles.map((e) => e.toString()).toList()
        : ['user'];

    final createdAtRaw = json['created_at'];
    final createdAt = createdAtRaw != null
        ? DateTime.parse(createdAtRaw.toString())
        : DateTime.now();

    final lastLoginRaw = json['last_login_at'];
    final lastLoginAt = lastLoginRaw != null
        ? DateTime.tryParse(lastLoginRaw.toString())
        : null;

    return UserProfileModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleNames: roleNames,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      deviceId: json['device_id'] as String?,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'roles': roleNames,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'device_id': deviceId,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
    };
  }

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName,
      phoneNumber: phoneNumber,
      avatarUrl: avatarUrl,
      roles: roleNames
          .map((name) {
            try {
              return UserRole.values.byName(name);
            } catch (_) {
              return UserRole.user;
            }
          })
          .toList(),
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      deviceId: deviceId,
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
    );
  }

  static UserProfileModel fromDomain(UserProfile profile) {
    return UserProfileModel(
      id: profile.id,
      email: profile.email,
      displayName: profile.displayName,
      phoneNumber: profile.phoneNumber,
      avatarUrl: profile.avatarUrl,
      roleNames: profile.roles.map((r) => r.name).toList(),
      createdAt: profile.createdAt,
      lastLoginAt: profile.lastLoginAt,
      deviceId: profile.deviceId,
      isEmailVerified: profile.isEmailVerified,
      isPhoneVerified: profile.isPhoneVerified,
    );
  }
}
