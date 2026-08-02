// path: test/features/incidents/incident_workflow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/incident_workflow.dart';

void main() {
  test('forward chain: Reported → Investigated → CAPA → Verified → Closed', () {
    expect(IncidentWorkflow.next(IncidentStatus.reported), IncidentStatus.investigated);
    expect(IncidentWorkflow.next(IncidentStatus.investigated), IncidentStatus.capa);
    expect(IncidentWorkflow.next(IncidentStatus.capa), IncidentStatus.verified);
    expect(IncidentWorkflow.next(IncidentStatus.verified), IncidentStatus.closed);
    expect(IncidentWorkflow.next(IncidentStatus.closed), isNull);
  });

  test('non-adjacent denied', () {
    expect(IncidentWorkflow.canTransition(from: IncidentStatus.reported, to: IncidentStatus.closed, roleRank: 5).allowed, isFalse);
  });

  group('close guard (Verified → Closed)', () {
    const from = IncidentStatus.verified;
    const to = IncidentStatus.closed;
    test('blocked without evidence', () {
      final c = IncidentWorkflow.canTransition(from: from, to: to, roleRank: 3,
          guard: const IncidentGuardContext(hasVerificationEvidence: false, allLinkedCapasClosed: true),);
      expect(c.allowed, isFalse);
    });
    test('blocked with open CAPA', () {
      final c = IncidentWorkflow.canTransition(from: from, to: to, roleRank: 3,
          guard: const IncidentGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: false),);
      expect(c.allowed, isFalse);
    });
    test('Supervisor cannot close', () {
      final c = IncidentWorkflow.canTransition(from: from, to: to, roleRank: 2,
          guard: const IncidentGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: true),);
      expect(c.allowed, isFalse);
    });
    test('Safety Officer with evidence + closed CAPAs can close', () {
      final c = IncidentWorkflow.canTransition(from: from, to: to, roleRank: 3,
          guard: const IncidentGuardContext(hasVerificationEvidence: true, allLinkedCapasClosed: true),);
      expect(c.allowed, isTrue);
    });
  });
}
