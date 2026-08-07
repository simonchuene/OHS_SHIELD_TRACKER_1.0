// path: test/features/dashboard/priority_item_json_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/priority_item.dart';

void main() {
  test('round-trips through JSON so the offline snapshot ranks identically', () {
    final original = [
      PriorityItem(
        kind: PriorityKind.capa,
        id: 'c1',
        title: 'Replace guard',
        subtitle: 'CAPA',
        severityRank: 3,
        statusLabel: 'In Progress',
        isOverdue: true,
        dueDate: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 5, 9, 30),
      ),
      PriorityItem(
        kind: PriorityKind.incident,
        id: 'i1',
        title: 'Spill',
        subtitle: 'Incident · Plant A',
        severityRank: 1,
        statusLabel: 'Reported',
        isOverdue: false,
        dueDate: null,
        updatedAt: DateTime(2026, 8, 6),
      ),
    ]..sort(PriorityItem.compare);

    final restored = [
      for (final i in original) PriorityItem.fromJson(i.toJson()),
    ]..sort(PriorityItem.compare);

    expect(restored.map((e) => e.id).toList(), original.map((e) => e.id).toList());

    final a = restored.first;
    expect(a.kind, PriorityKind.capa);
    expect(a.title, 'Replace guard');
    expect(a.subtitle, 'CAPA');
    expect(a.severityRank, 3);
    expect(a.statusLabel, 'In Progress');
    expect(a.isOverdue, isTrue);
    expect(a.dueDate, DateTime(2026, 8, 1));
    expect(a.updatedAt, DateTime(2026, 8, 5, 9, 30));
  });

  test('tolerates a malformed snapshot entry without throwing', () {
    final item = PriorityItem.fromJson({'id': 'x', 'title': 't', 'subtitle': 's'});
    expect(item.kind, PriorityKind.hazard); // safe default
    expect(item.severityRank, 0);
    expect(item.isOverdue, isFalse);
  });
}
