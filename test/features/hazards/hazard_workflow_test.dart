// path: test/features/hazards/hazard_workflow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart';

void main() {
  const supervisor = 2;
  const safetyOfficer = 3;

  test('forward chain matches locked status flow', () {
    expect(HazardWorkflow.next(HazardStatus.draft), HazardStatus.submitted);
    expect(HazardWorkflow.next(HazardStatus.submitted), HazardStatus.assessment);
    expect(HazardWorkflow.next(HazardStatus.assessment), HazardStatus.investigation);
    expect(HazardWorkflow.next(HazardStatus.investigation), HazardStatus.capa);
    expect(HazardWorkflow.next(HazardStatus.capa), HazardStatus.verification);
    expect(HazardWorkflow.next(HazardStatus.verification), HazardStatus.closed);
    expect(HazardWorkflow.next(HazardStatus.closed), isNull);
  });

  test('non-adjacent and from-closed transitions are denied', () {
    expect(HazardWorkflow.canTransition(from: HazardStatus.draft, to: HazardStatus.closed, roleRank: 5).allowed, isFalse);
    expect(HazardWorkflow.canTransition(from: HazardStatus.closed, to: HazardStatus.submitted, roleRank: 5).allowed, isFalse);
  });

  test('role gates: submit any, mid-stages Supervisor+, close Safety Officer+', () {
    expect(HazardWorkflow.canTransition(from: HazardStatus.draft, to: HazardStatus.submitted, roleRank: AppRole.employee.rank).allowed, isTrue);
    expect(HazardWorkflow.canTransition(from: HazardStatus.submitted, to: HazardStatus.assessment, roleRank: 1).allowed, isFalse);
    expect(HazardWorkflow.canTransition(from: HazardStatus.submitted, to: HazardStatus.assessment, roleRank: supervisor).allowed, isTrue);
  });

  group('close guard', () {
    const from = HazardStatus.verification;
    const to = HazardStatus.closed;
    test('blocked without verification evidence', () {
      final c = HazardWorkflow.canTransition(
        from: from, to: to, roleRank: safetyOfficer,
        guard: const HazardGuardContext(hasVerificationEvidence: false, allLinkedCapasClosed: true),
      );
      expect(c.allowed, isFalse);
      expect(c.reason, contains('evidence'));
    });
    test('blocked while a linked CAPA is open', () {
      final c = HazardWorkflow.canTransition(
        from: from, to: to, roleRank: safetyOfficer,
        guard: const HazardGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: false),
      );
      expect(c.allowed, isFalse);
      expect(c.reason, contains('corrective actions'));
    });
    test('blocked for Supervisor even when guards pass', () {
      final c = HazardWorkflow.canTransition(
        from: from, to: to, roleRank: supervisor,
        guard: const HazardGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: true),
      );
      expect(c.allowed, isFalse);
    });
    test('allowed for Safety Officer with evidence + closed CAPAs', () {
      final c = HazardWorkflow.canTransition(
        from: from, to: to, roleRank: safetyOfficer,
        guard: const HazardGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: true),
      );
      expect(c.allowed, isTrue);
    });
  });
}
