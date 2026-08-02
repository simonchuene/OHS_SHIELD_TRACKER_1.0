// path: test/features/dashboard/safety_score_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_scope.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/safety_score.dart';

void main() {
  group('SafetyScore', () {
    test('perfect when no risk drivers', () {
      expect(SafetyScore.compute(highRiskHazards: 0, overdueCapas: 0, seriousIncidents30d: 0), 100);
    });
    test('deducts weighted penalties', () {
      // 2*5 + 3*4 + 1*6 = 28 → 72
      expect(SafetyScore.compute(highRiskHazards: 2, overdueCapas: 3, seriousIncidents30d: 1), 72);
    });
    test('clamps at 0', () {
      expect(SafetyScore.compute(highRiskHazards: 50, overdueCapas: 50, seriousIncidents30d: 50), 0);
    });
  });

  group('DashboardScope', () {
    test('labels per role', () {
      expect(DashboardScope.labelFor(AppRole.employee), 'My contributions');
      expect(DashboardScope.labelFor(AppRole.supervisor), 'My department');
      expect(DashboardScope.labelFor(AppRole.safetyOfficer), 'My site');
      expect(DashboardScope.labelFor(AppRole.manager), 'Enterprise');
    });
    test('dept ranking only for Safety Officer and above', () {
      expect(DashboardScope.showsDeptRanking(AppRole.supervisor), isFalse);
      expect(DashboardScope.showsDeptRanking(AppRole.safetyOfficer), isTrue);
      expect(DashboardScope.showsSystemHealth(AppRole.administrator), isTrue);
      expect(DashboardScope.showsSystemHealth(AppRole.manager), isFalse);
    });
  });
}
