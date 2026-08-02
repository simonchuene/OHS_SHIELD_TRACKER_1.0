// path: test/features/audit/audit_diff_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_log_entry.dart';

void main() {
  test('detects changed fields, ignores updated_at/version noise', () {
    final diff = AuditDiff.compute(
      {'status': 'submitted', 'title': 'X', 'version': 1, 'updated_at': 'a'},
      {'status': 'closed', 'title': 'X', 'version': 2, 'updated_at': 'b'},
    );
    expect(diff.map((c) => c.field), ['status']);
    expect(diff.first.before, 'submitted');
    expect(diff.first.after, 'closed');
  });

  test('added and removed fields', () {
    final diff = AuditDiff.compute({'a': '1'}, {'a': '1', 'b': '2'});
    final b = diff.firstWhere((c) => c.field == 'b');
    expect(b.isAdded, isTrue);
    expect(b.before, isNull);
    expect(b.after, '2');
  });

  test('insert (null before) shows all after fields as additions', () {
    final diff = AuditDiff.compute(null, {'title': 'New hazard', 'status': 'submitted'});
    expect(diff.length, 2);
    expect(diff.every((c) => c.isAdded), isTrue);
  });

  test('no changes → empty diff', () {
    expect(AuditDiff.compute({'x': '1'}, {'x': '1'}), isEmpty);
  });
}
