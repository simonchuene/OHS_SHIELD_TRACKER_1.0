// path: test/features/capa/capa_escalation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/capa/domain/capa_escalation.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';

void main() {
  CorrectiveAction capa({required CapaStatus status, required CapaPriority priority, DateTime? due}) =>
      CorrectiveAction(id: 'c', companyId: 'co', description: 'd', priority: priority, status: status, dueDate: due, hazardId: 'h');

  final now = DateTime(2026, 8, 1, 12);

  test('closed never escalates', () {
    expect(CapaEscalationRules.evaluate(capa(status: CapaStatus.closed, priority: CapaPriority.critical, due: now.subtract(const Duration(days: 5))), now), CapaEscalation.none);
  });
  test('critical priority escalates', () {
    expect(CapaEscalationRules.evaluate(capa(status: CapaStatus.inProgress, priority: CapaPriority.critical), now), CapaEscalation.critical);
  });
  test('overdue when past due', () {
    final e = CapaEscalationRules.evaluate(capa(status: CapaStatus.assigned, priority: CapaPriority.medium, due: now.subtract(const Duration(days: 1))), now);
    expect(e, CapaEscalation.overdue);
    expect(CapaEscalationRules.shouldNotify(e), isTrue);
  });
  test('due soon within 2 days', () {
    expect(CapaEscalationRules.evaluate(capa(status: CapaStatus.assigned, priority: CapaPriority.low, due: now.add(const Duration(days: 1))), now), CapaEscalation.dueSoon);
  });
  test('not overdue on the due date itself (due today)', () {
    final e = CapaEscalationRules.evaluate(
      capa(status: CapaStatus.assigned, priority: CapaPriority.medium, due: DateTime(2026, 8, 1)),
      DateTime(2026, 8, 1, 23, 59),
    );
    expect(e, isNot(CapaEscalation.overdue));
  });
  test('overdue the day after the due date', () {
    final e = CapaEscalationRules.evaluate(
      capa(status: CapaStatus.assigned, priority: CapaPriority.medium, due: DateTime(2026, 8, 1)),
      DateTime(2026, 8, 2, 0, 1),
    );
    expect(e, CapaEscalation.overdue);
  });
  test('no due date, non-critical → none', () {
    expect(CapaEscalationRules.evaluate(capa(status: CapaStatus.assigned, priority: CapaPriority.medium), now), CapaEscalation.none);
  });
}
