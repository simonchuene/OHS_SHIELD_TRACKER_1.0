// path: test/features/capa/capa_workflow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/capa/domain/capa_workflow.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';

void main() {
  test('forward chain', () {
    expect(CapaWorkflow.next(CapaStatus.created), CapaStatus.assigned);
    expect(CapaWorkflow.next(CapaStatus.assigned), CapaStatus.inProgress);
    expect(CapaWorkflow.next(CapaStatus.inProgress), CapaStatus.verification);
    expect(CapaWorkflow.next(CapaStatus.verification), CapaStatus.closed);
    expect(CapaWorkflow.next(CapaStatus.closed), isNull);
  });

  test('assign requires an owner', () {
    final noOwner = CapaWorkflow.canTransition(
        from: CapaStatus.created, to: CapaStatus.assigned, roleRank: 2, guard: const CapaGuardContext(hasOwner: false),);
    expect(noOwner.allowed, isFalse);
    final withOwner = CapaWorkflow.canTransition(
        from: CapaStatus.created, to: CapaStatus.assigned, roleRank: 2, guard: const CapaGuardContext(hasOwner: true),);
    expect(withOwner.allowed, isTrue);
  });

  test('verification and closed require Safety Officer+ (rank 3)', () {
    expect(CapaWorkflow.canTransition(from: CapaStatus.inProgress, to: CapaStatus.verification, roleRank: 2).allowed, isFalse);
    expect(CapaWorkflow.canTransition(from: CapaStatus.inProgress, to: CapaStatus.verification, roleRank: 3).allowed, isTrue);
    expect(CapaWorkflow.minRankFor(CapaStatus.closed), 3);
  });

  test('close requires verification evidence', () {
    final noEvidence = CapaWorkflow.canTransition(
        from: CapaStatus.verification, to: CapaStatus.closed, roleRank: 3, guard: const CapaGuardContext(hasVerificationEvidence: false),);
    expect(noEvidence.allowed, isFalse);
    final withEvidence = CapaWorkflow.canTransition(
        from: CapaStatus.verification, to: CapaStatus.closed, roleRank: 3, guard: const CapaGuardContext(hasVerificationEvidence: true),);
    expect(withEvidence.allowed, isTrue);
  });

  test('closed is terminal; non-adjacent denied', () {
    expect(CapaWorkflow.canTransition(from: CapaStatus.closed, to: CapaStatus.verification, roleRank: 5).allowed, isFalse);
    expect(CapaWorkflow.canTransition(from: CapaStatus.created, to: CapaStatus.closed, roleRank: 5).allowed, isFalse);
  });
}
