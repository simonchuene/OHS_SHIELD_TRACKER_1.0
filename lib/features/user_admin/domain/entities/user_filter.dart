// path: lib/features/user_admin/domain/entities/user_filter.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';

/// Filter/search criteria for the User List (by site, department, role, status,
/// free-text). Immutable; use [copyWith].
class UserFilter {
  const UserFilter({
    this.siteId,
    this.departmentId,
    this.role,
    this.status,
    this.query,
  });

  final String? siteId;
  final String? departmentId;
  final AppRole? role;
  final UserStatus? status;
  final String? query;

  bool get isEmpty =>
      siteId == null && departmentId == null && role == null && status == null && (query?.isEmpty ?? true);

  UserFilter copyWith({
    String? siteId,
    String? departmentId,
    AppRole? role,
    UserStatus? status,
    String? query,
    bool clearSite = false,
    bool clearDepartment = false,
    bool clearRole = false,
    bool clearStatus = false,
  }) {
    return UserFilter(
      siteId: clearSite ? null : (siteId ?? this.siteId),
      departmentId: clearDepartment ? null : (departmentId ?? this.departmentId),
      role: clearRole ? null : (role ?? this.role),
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
    );
  }
}

/// Parameters for inviting a new user (admin-provisioned).
class InviteUserParams {
  const InviteUserParams({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.jobTitle,
    this.phone,
    this.siteId,
    this.departmentId,
    this.roleSiteId,
    this.roleDepartmentId,
  });

  final String email;
  final String firstName;
  final String lastName;
  final AppRole role;
  final String? jobTitle;
  final String? phone;
  final String? siteId; // home site
  final String? departmentId; // home department
  final String? roleSiteId; // role scope
  final String? roleDepartmentId;

  Map<String, dynamic> toInvitePayload() => {
        'action': 'invite',
        'email': email.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'jobTitle': jobTitle,
        'phone': phone,
        'siteId': siteId,
        'departmentId': departmentId,
        'role': role.code,
        'roleSiteId': roleSiteId,
        'roleDepartmentId': roleDepartmentId,
      };
}
