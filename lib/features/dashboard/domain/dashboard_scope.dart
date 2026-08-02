// path: lib/features/dashboard/domain/dashboard_scope.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';

/// Maps the caller's role to a dashboard scope label (Prompt 13 table). The
/// actual row scoping is enforced by RLS (own→dept→site→enterprise), so the
/// same queries return role-appropriate data automatically — this only labels it.
abstract final class DashboardScope {
  static String labelFor(AppRole? role) => switch (role) {
        AppRole.employee => 'My contributions',
        AppRole.supervisor => 'My department',
        AppRole.safetyOfficer => 'My site',
        AppRole.manager => 'Enterprise',
        AppRole.administrator => 'Enterprise',
        null => 'My contributions',
      };

  /// Employees see a personal view (no department ranking / site KPIs).
  static bool showsDeptRanking(AppRole? role) => (role?.rank ?? 0) >= AppRole.safetyOfficer.rank;
  static bool showsSystemHealth(AppRole? role) => role == AppRole.administrator;
}
