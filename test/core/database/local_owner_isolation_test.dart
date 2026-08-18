// path: test/core/database/local_owner_isolation_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';

/// The offline cache is not tenant-scoped: [CachedRecords] is keyed only by
/// (entityType, entityId), and every list screen merges it wholesale into its
/// results. That is safe only while the store holds a single user's data, so
/// these tests pin the guard that enforces it — a user switch leaking the
/// previous account's rows is a cross-company disclosure, not a display glitch.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> cache(String id) => db.upsertCache(
        CachedRecordsCompanion(
          entityType: const Value('hazard'),
          entityId: Value(id),
          data: const Value('{}'),
        ),
      );

  Future<int> cachedCount() async => (await db.cachedByType('hazard')).length;

  test('first claim on an empty store keeps it and reports no wipe', () async {
    expect(await db.claimForUser('user-a'), isFalse);
    await cache('h1');
    expect(await cachedCount(), 1);
  });

  test('re-claiming for the same user preserves the cache', () async {
    await db.claimForUser('user-a');
    await cache('h1');

    expect(await db.claimForUser('user-a'), isFalse);
    expect(await cachedCount(), 1, reason: 'same user must keep working offline');
  });

  test('a different user wipes the previous account cache', () async {
    await db.claimForUser('user-a');
    await cache('h1');

    expect(await db.claimForUser('user-b'), isTrue);
    expect(await cachedCount(), 0,
        reason: "company A's rows must not survive into B's session");
  });

  test('a different user wipes the outbox too', () async {
    await db.claimForUser('user-a');
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      id: 'q1',
      companyId: 'company-a',
      userId: 'user-a',
      entityType: 'hazard',
      entityId: 'h1',
      operation: 'insert',
      payload: '{}',
    ),);

    await db.claimForUser('user-b');
    expect(await db.dueEntries(DateTime.now()), isEmpty,
        reason: "A's queued mutation would be pushed under B's session");
  });

  test('unowned pre-existing data is discarded rather than adopted', () async {
    // An install predating the owner row: the data may belong to anyone.
    await cache('h1');
    expect(await db.claimForUser('user-a'), isTrue);
    expect(await cachedCount(), 0);
  });

  test('sign-out leaves nothing for the next user', () async {
    await db.claimForUser('user-a');
    await cache('h1');

    await db.releaseLocalData();
    expect(await cachedCount(), 0);
    // And the store is unowned, so the next sign-in claims a clean slate.
    expect(await db.claimForUser('user-b'), isFalse);
  });

  test('the drain filter ignores another user\'s entries', () async {
    for (final (id, user) in [('q1', 'user-a'), ('q2', 'user-b')]) {
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        id: id,
        companyId: 'company-x',
        userId: user,
        entityType: 'hazard',
        entityId: 'h-$id',
        operation: 'insert',
        payload: '{}',
      ),);
    }

    final mine = await db.dueEntries(DateTime.now(), userId: 'user-a');
    expect(mine.map((e) => e.id), ['q1']);
  });
}
