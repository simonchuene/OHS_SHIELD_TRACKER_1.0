// path: test/features/dashboard/priority_sort_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/priority_item.dart';

void main() {
  PriorityItem item({int severity = 1, bool overdue = false, DateTime? due, DateTime? updated}) => PriorityItem(
        kind: PriorityKind.capa,
        id: 'x',
        title: 't',
        subtitle: 's',
        severityRank: severity,
        statusLabel: 'S',
        isOverdue: overdue,
        dueDate: due,
        updatedAt: updated ?? DateTime(2026, 1, 1),
      );

  List<PriorityItem> sorted(List<PriorityItem> l) => [...l]..sort(PriorityItem.compare);

  test('severity descending — Critical → High → Medium → Low', () {
    final result = sorted([item(severity: 0), item(severity: 3), item(severity: 1), item(severity: 2)]);
    expect(result.map((e) => e.severityRank).toList(), [3, 2, 1, 0]);
  });

  test('overdue ranks above on-track within the same severity', () {
    final result = sorted([item(severity: 2, overdue: false), item(severity: 2, overdue: true)]);
    expect(result.first.isOverdue, isTrue);
  });

  test('soonest due date first within the same severity + overdue', () {
    final result = sorted([
      item(severity: 2, overdue: true, due: DateTime(2026, 8, 10)),
      item(severity: 2, overdue: true, due: DateTime(2026, 8, 6)),
    ]);
    expect(result.first.dueDate, DateTime(2026, 8, 6));
  });

  test('an item with a due date ranks ahead of one without', () {
    final result = sorted([item(severity: 2, due: null), item(severity: 2, due: DateTime(2026, 8, 20))]);
    expect(result.first.dueDate, isNotNull);
  });

  test('most recently updated is the final tie-breaker', () {
    final result = sorted([
      item(severity: 1, updated: DateTime(2026, 8, 1)),
      item(severity: 1, updated: DateTime(2026, 8, 5)),
    ]);
    expect(result.first.updatedAt, DateTime(2026, 8, 5));
  });
}
