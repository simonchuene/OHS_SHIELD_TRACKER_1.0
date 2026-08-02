// path: lib/features/user_admin/domain/entities/role_assignment.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';

part 'role_assignment.freezed.dart';

/// A scope-aware role grant (maps to a `user_roles` row). NULL site & department
/// = company-wide; a populated site/department restricts the role to that scope.
@freezed
class RoleAssignment with _$RoleAssignment {
  const RoleAssignment._();

  const factory RoleAssignment({
    required AppRole role,
    String? siteId,
    String? departmentId,
  }) = _RoleAssignment;

  bool get isCompanyWide => siteId == null && departmentId == null;

  String get scopeLabel => switch ((siteId, departmentId)) {
        (null, null) => 'Company-wide',
        (_, final d?) when d.isNotEmpty => 'Department-scoped',
        _ => 'Site-scoped',
      };
}
