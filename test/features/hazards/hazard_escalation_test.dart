// path: test/features/hazards/hazard_escalation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_escalation.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

void main() {
  Hazard h({
    required HazardStatus status,
    RiskBand? risk,
    required DateTime reportedAt,
  }) =>
      Hazard(
        id: 'h', companyId: 'c', title: 't', category: HazardCategory.physical,
        status: status, riskLevel: risk, reporterId: 'u', reportedAt: reportedAt,
      );

  final now = DateTime(2026, 8, 1, 12);

  test('closed hazards never escalate', () {
    expect(HazardEscalation.evaluate(h(status: HazardStatus.closed, reportedAt: DateTime(2020)), now),
        EscalationLevel.none,);
  });

  test('critical risk always escalates critical', () {
    expect(
      HazardEscalation.evaluate(h(status: HazardStatus.assessment, risk: RiskBand.critical, reportedAt: now), now),
      EscalationLevel.critical,
    );
  });

  test('overdue when stage age exceeds SLA', () {
    // assessment SLA = 3 days; reported 5 days ago
    final e = HazardEscalation.evaluate(
      h(status: HazardStatus.assessment, risk: RiskBand.medium, reportedAt: now.subtract(const Duration(days: 5))),
      now,
    );
    expect(e, EscalationLevel.overdue);
    expect(HazardEscalation.shouldNotify(e), isTrue);
  });

  test('fresh hazard within SLA is none', () {
    final e = HazardEscalation.evaluate(
      h(status: HazardStatus.capa, risk: RiskBand.low, reportedAt: now.subtract(const Duration(days: 1))),
      now,
    );
    expect(e, EscalationLevel.none);
  });
}
