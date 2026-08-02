// path: lib/features/user_admin/domain/entities/managed_user.dart
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/role_assignment.dart';

part 'managed_user.freezed.dart';

/// A user as seen by an Administrator in the User & Access Administration module.
/// Always bound to exactly one company (enforced by RLS/company scoping); may
/// hold multiple scope-aware role assignments.
@freezed
class ManagedUser with _$ManagedUser {
  const ManagedUser._();

  const factory ManagedUser({
    required String id,
    required String email,
    required String firstName,
    required String lastName,
    String? jobTitle,
    String? phone,
    String? siteId,
    String? departmentId,
    required UserStatus status,
    @Default(<RoleAssignment>[]) List<RoleAssignment> roles,
  }) = _ManagedUser;

  String get displayName {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? email : n;
  }

  int get highestRank =>
      roles.isEmpty ? 0 : roles.map((r) => r.role.rank).reduce(max);

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final i = (f + l).toUpperCase();
    return i.isEmpty ? '?' : i;
  }
}
