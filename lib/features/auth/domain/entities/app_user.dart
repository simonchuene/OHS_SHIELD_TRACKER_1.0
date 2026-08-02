// path: lib/features/auth/domain/entities/app_user.dart
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';

part 'app_user.freezed.dart';

/// The authenticated application user: identity (from auth.users) + profile
/// (company/site/department scope, status) + scope-aware roles. Immutable
/// domain entity — no JSON concerns (those live in DTOs).
@freezed
class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String id,
    required String email,
    required String companyId,
    String? siteId,
    String? departmentId,
    required String firstName,
    required String lastName,
    required UserStatus status,
    @Default(<AppRole>[]) List<AppRole> roles,
  }) = _AppUser;

  /// Highest authority rank across all scope-aware role assignments (0 = none).
  int get highestRank =>
      roles.isEmpty ? 0 : roles.map((r) => r.rank).reduce(max);

  AppRole? get primaryRole {
    if (roles.isEmpty) return null;
    return roles.reduce((a, b) => a.rank >= b.rank ? a : b);
  }

  bool get isActive => status.canSignIn;
  String get displayName => '$firstName $lastName'.trim();
  String get firstNameOrEmail => firstName.isNotEmpty ? firstName : email;

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final i = (f + l).toUpperCase();
    return i.isEmpty ? '?' : i;
  }
}
