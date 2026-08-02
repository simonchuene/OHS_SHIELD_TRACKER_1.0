// path: lib/features/auth/domain/entities/app_role.dart
/// The five locked RBAC roles (Master Prompt). `rank` is the escalation/authority
/// order used by RLS (`app.user_rank()`) and by client-side conditional
/// rendering. `code` matches the `role_code` enum / `roles.code` in the DB.
enum AppRole {
  employee('employee', 1),
  supervisor('supervisor', 2),
  safetyOfficer('safety_officer', 3),
  manager('manager', 4),
  administrator('administrator', 5);

  const AppRole(this.code, this.rank);

  final String code;
  final int rank;

  static AppRole fromCode(String code) => AppRole.values.firstWhere(
        (r) => r.code == code,
        orElse: () => AppRole.employee,
      );

  // Capability helpers mirroring the permission matrix thresholds (server RLS is
  // authoritative; these drive conditional UI only — Prompt 3).
  bool get canAssess => rank >= AppRole.supervisor.rank;
  bool get canInvestigate => rank >= AppRole.supervisor.rank;
  bool get canManageCapa => rank >= AppRole.supervisor.rank;
  bool get canVerifyClose => rank >= AppRole.safetyOfficer.rank;
  bool get canViewAudit => rank >= AppRole.safetyOfficer.rank;
  bool get canAdministerUsers => rank >= AppRole.administrator.rank;
}
