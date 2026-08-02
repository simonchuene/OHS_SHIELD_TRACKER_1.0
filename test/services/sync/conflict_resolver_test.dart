// path: test/services/sync/conflict_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/services/sync/conflict_resolver.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';

void main() {
  const resolver = ConflictResolver();
  final t0 = DateTime.utc(2026, 1, 1, 10);
  final t1 = DateTime.utc(2026, 1, 1, 11); // later

  test('no conflict -> ApplyLocal', () {
    final r = resolver.resolveUpdate(
      entityType: SyncEntity.hazard,
      changedFields: {'title': 'x'},
      baseVersion: 3,
      serverRow: {'id': 'h1', 'version': 3, 'updated_at': t0.toIso8601String()},
      localUpdatedAt: t1,
    );
    expect(r, isA<ApplyLocal>());
  });

  test('LWW conflict, local newer -> ApplyLocal', () {
    final r = resolver.resolveUpdate(
      entityType: SyncEntity.hazard,
      changedFields: {'title': 'local'},
      baseVersion: 3,
      serverRow: {'id': 'h1', 'version': 4, 'updated_at': t0.toIso8601String()},
      localUpdatedAt: t1,
    );
    expect(r, isA<ApplyLocal>());
  });

  test('LWW conflict, server newer -> AcceptServer', () {
    final r = resolver.resolveUpdate(
      entityType: SyncEntity.incident,
      changedFields: {'description': 'local'},
      baseVersion: 3,
      serverRow: {'id': 'i1', 'version': 4, 'updated_at': t1.toIso8601String()},
      localUpdatedAt: t0,
    );
    expect(r, isA<AcceptServer>());
  });

  test('field-merge conflict -> ApplyLocal (touched fields win)', () {
    final r = resolver.resolveUpdate(
      entityType: SyncEntity.correctiveAction,
      changedFields: {'status': 'in_progress'},
      baseVersion: 2,
      serverRow: {'id': 'c1', 'version': 5, 'updated_at': t1.toIso8601String()},
      localUpdatedAt: t0, // older, but field-merge still applies the diff
    );
    expect(r, isA<ApplyLocal>());
  });

  test('missing server row -> Unresolvable', () {
    final r = resolver.resolveUpdate(
      entityType: SyncEntity.hazard,
      changedFields: {'title': 'x'},
      baseVersion: 1,
      serverRow: null,
      localUpdatedAt: t1,
    );
    expect(r, isA<Unresolvable>());
  });
}
