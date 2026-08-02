// path: test/security/rbac_matrix_test.dart
// Runnable encoding of the Master Prompt permission matrix. Validates the
// client-side capability model (AppRole) that drives conditional rendering AND
// the rank thresholds the workflows enforce. RLS is the authoritative gate
// (see supabase/tests/rls_smoke_test.sql), but this proves the client model
// never *offers* an action the matrix forbids.
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';

void main() {
  const roles = AppRole.values;

  // Master Prompt matrix → minimum rank required (0 = all authenticated).
  const minRank = {
    'report_hazard_incident': 1,
    'perform_risk_assessment': 2,
    'conduct_investigation': 2,
    'create_assign_capa': 2,
    'verify_close_capa': 3,
    'close_hazard_incident': 3,
    'conduct_inspections': 2,
    'view_department_records': 2,
    'view_site_enterprise': 3,
    'manage_users_roles': 5,
    'view_audit_log': 3,
  };

  bool allowed(AppRole r, String action) => r.rank >= minRank[action]!;

  test('every role × action resolves per the matrix', () {
    // Spot-check the locked cells for each role.
    expect(allowed(AppRole.employee, 'report_hazard_incident'), isTrue);
    expect(allowed(AppRole.employee, 'perform_risk_assessment'), isFalse);
    expect(allowed(AppRole.supervisor, 'create_assign_capa'), isTrue);
    expect(allowed(AppRole.supervisor, 'verify_close_capa'), isFalse);
    expect(allowed(AppRole.safetyOfficer, 'verify_close_capa'), isTrue);
    expect(allowed(AppRole.safetyOfficer, 'manage_users_roles'), isFalse);
    expect(allowed(AppRole.manager, 'view_site_enterprise'), isTrue);
    expect(allowed(AppRole.manager, 'manage_users_roles'), isFalse);
    expect(allowed(AppRole.administrator, 'manage_users_roles'), isTrue);
  });

  test('AppRole capability helpers match the matrix thresholds', () {
    for (final r in roles) {
      expect(r.canAssess, allowed(r, 'perform_risk_assessment'), reason: '${r.code} canAssess');
      expect(r.canInvestigate, allowed(r, 'conduct_investigation'), reason: '${r.code} canInvestigate');
      expect(r.canManageCapa, allowed(r, 'create_assign_capa'), reason: '${r.code} canManageCapa');
      expect(r.canVerifyClose, allowed(r, 'verify_close_capa'), reason: '${r.code} canVerifyClose');
      expect(r.canViewAudit, allowed(r, 'view_audit_log'), reason: '${r.code} canViewAudit');
      expect(r.canAdministerUsers, allowed(r, 'manage_users_roles'), reason: '${r.code} canAdministerUsers');
    }
  });

  test('rank ladder is strictly ordered employee<...<administrator', () {
    expect([for (final r in roles) r.rank], [1, 2, 3, 4, 5]);
  });
}
