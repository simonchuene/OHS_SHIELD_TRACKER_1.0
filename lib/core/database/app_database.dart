// path: lib/core/database/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local outbox mirroring the server-side `sync_queue` table (Master Prompt
/// OFFLINE SYNCHRONIZATION). One row per pending mutation.
class SyncQueueEntries extends Table {
  TextColumn get id => text()(); // client-minted uuid
  TextColumn get companyId => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()(); // 'hazard' | 'incident' | 'inspection' | 'corrective_action' | ...
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // insert | update | delete
  TextColumn get payload => text()(); // JSON — full row (insert) or changed-fields diff (update)
  IntColumn get baseVersion => integer().nullable()(); // version the client edited from (D4)
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|syncing|synced|failed
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline-readable cache + per-record sync status surfaced in the UI
/// (pending/syncing/synced/failed). Keyed by (entityType, entityId). Feature
/// modules may add typed Drift tables later for complex queries; this generic
/// store powers the engine and the status badges now.
class CachedRecords extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get data => text()(); // JSON snapshot of the record
  IntColumn get version => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

/// Offline queue for binary attachment uploads (Prompt 6). Distinct from
/// [SyncQueueEntries] because it carries a local file path, not a JSON row.
class PendingUploads extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get ownerType => text()();
  TextColumn get ownerId => text()();
  TextColumn get attachmentId => text().nullable()(); // set = upload as a new version
  TextColumn get localPath => text()();
  TextColumn get fileName => text()();
  TextColumn get contentType => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get uploadedBy => text().nullable()();
  RealColumn get gpsLat => real().nullable()();
  RealColumn get gpsLng => real().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Locally-stored report history (Prompt 14). Doubles as offline access — the
/// saved CSV/PDF files remain openable without connectivity.
class ReportHistoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get reportType => text()();
  TextColumn get title => text()();
  TextColumn get format => text()(); // 'csv' | 'pdf'
  TextColumn get filePath => text()();
  DateTimeColumn get generatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Which signed-in user this device's local data belongs to. Single row.
///
/// The cache is not tenant-scoped — [CachedRecords] is keyed only by
/// (entityType, entityId), and every list screen merges the whole cache into
/// its results. That is safe only while the cache holds exactly one user's
/// data, so this row is the guard: when a *different* user signs in, the local
/// store is wiped before anything can read it. Without it, signing into
/// company B on a device that previously held company A's data renders A's
/// rows alongside B's, since the server filter never sees the cached copies.
///
/// Kept in Drift rather than secure storage so the check and the wipe happen in
/// one transaction, and so it survives the app being killed mid-switch.
class LocalOwner extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))(); // always 0
  TextColumn get userId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
    tables: [SyncQueueEntries, CachedRecords, PendingUploads, ReportHistoryEntries, LocalOwner],)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(pendingUploads);
          if (from < 3) await m.createTable(reportHistoryEntries);
          if (from < 4) {
            await m.createTable(localOwner);
            // Existing installs carry data whose owner was never recorded. It
            // may belong to anyone, so it cannot be trusted: drop it and let
            // the next sign-in repopulate from the server.
            await clearLocalData();
          }
        },
      );

  // --- Tenant/user isolation of local data --------------------------------

  /// Wipes every trace of the previous user's data. Deliberately includes the
  /// outbox: a queued mutation carries the old user's `company_id`, so pushing
  /// it under a new session can only ever fail RLS, and leaving it behind means
  /// a permanent unexplained sync failure.
  Future<void> clearLocalData() async {
    await batch((b) {
      b.deleteWhere(cachedRecords, (_) => const Constant(true));
      b.deleteWhere(syncQueueEntries, (_) => const Constant(true));
      b.deleteWhere(pendingUploads, (_) => const Constant(true));
      b.deleteWhere(reportHistoryEntries, (_) => const Constant(true));
    });
  }

  /// Claims the local store for [userId], clearing it first if it currently
  /// belongs to someone else. Call before any cached read for a newly resolved
  /// session. Returns true when data was discarded.
  ///
  /// A missing owner row means the store predates this check (or was just
  /// cleared), so it is claimed without a wipe only when it is also empty;
  /// otherwise the data is of unknown origin and goes.
  Future<bool> claimForUser(String userId) async {
    return transaction(() async {
      final current = await select(localOwner).getSingleOrNull();
      if (current?.userId == userId) return false;

      final hadData = current != null ||
          await (selectOnly(cachedRecords)..addColumns([cachedRecords.entityId]))
              .get()
              .then((r) => r.isNotEmpty);
      if (hadData) await clearLocalData();

      await into(localOwner).insertOnConflictUpdate(
        LocalOwnerCompanion(id: const Value(0), userId: Value(userId)),
      );
      return hadData;
    });
  }

  /// Releases the store on sign-out so nothing survives to be shown to whoever
  /// signs in next — including on a device that is handed over.
  Future<void> releaseLocalData() async {
    await clearLocalData();
    await delete(localOwner).go();
  }

  // --- Outbox -------------------------------------------------------------

  Future<void> enqueue(SyncQueueEntriesCompanion entry) =>
      into(syncQueueEntries).insert(entry);

  /// Pending entries whose backoff window has elapsed, oldest first (FIFO).
  ///
  /// [userId] restricts the drain to the signed-in user's own mutations. Entries
  /// are pushed under whatever session is current, so an entry authored by a
  /// different user would be sent with the wrong identity — the server refuses
  /// it (42501), but the entry then retries forever. `claimForUser` normally
  /// clears these already; this is the second line of defence.
  Future<List<SyncQueueEntry>> dueEntries(DateTime now, {String? userId}) {
    return (select(syncQueueEntries)
          ..where((t) {
            final due = t.status.equals('pending') &
                (t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now));
            return userId == null ? due : due & t.userId.equals(userId);
          })
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> updateEntry(String id, SyncQueueEntriesCompanion patch) {
    return (update(syncQueueEntries)..where((t) => t.id.equals(id)))
        .write(patch.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteEntry(String id) =>
      (delete(syncQueueEntries)..where((t) => t.id.equals(id))).go();

  Future<int> pendingCount() async {
    final rows = await (select(syncQueueEntries)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed')))
        .get();
    return rows.length;
  }

  // --- Cache / per-record status -----------------------------------------

  Future<void> upsertCache(CachedRecordsCompanion record) {
    return into(cachedRecords).insertOnConflictUpdate(record);
  }

  Future<void> setRecordStatus(String entityType, String entityId, String status) {
    return (update(cachedRecords)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId)))
        .write(CachedRecordsCompanion(
      syncStatus: Value(status),
      updatedAt: Value(DateTime.now()),
    ),);
  }

  // --- Pending attachment uploads (offline) ------------------------------

  Future<void> enqueuePendingUpload(PendingUploadsCompanion entry) =>
      into(pendingUploads).insert(entry);

  Future<List<PendingUpload>> duePendingUploads(DateTime now) {
    return (select(pendingUploads)
          ..where((t) => t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> updatePendingUpload(String id, PendingUploadsCompanion patch) =>
      (update(pendingUploads)..where((t) => t.id.equals(id))).write(patch);

  Future<void> deletePendingUpload(String id) =>
      (delete(pendingUploads)..where((t) => t.id.equals(id))).go();

  Stream<int> watchPendingUploadCount() =>
      pendingUploads.count().watchSingle();

  // --- Report history (local) --------------------------------------------

  Future<void> insertReport(ReportHistoryEntriesCompanion entry) =>
      into(reportHistoryEntries).insert(entry);

  Future<List<ReportHistoryEntry>> listReports() =>
      (select(reportHistoryEntries)..orderBy([(t) => OrderingTerm.desc(t.generatedAt)])).get();

  /// Locally-cached records of a type (used to surface offline-created/pending
  /// rows in list screens before they sync). Newest first.
  Future<List<CachedRecord>> cachedByType(String entityType) {
    return (select(cachedRecords)
          ..where((t) => t.entityType.equals(entityType))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Reactive per-record sync status for the UI badge (Prompt 3 §9.4).
  Stream<String?> watchRecordStatus(String entityType, String entityId) {
    return (select(cachedRecords)
          ..where((t) => t.entityType.equals(entityType) & t.entityId.equals(entityId)))
        .watchSingleOrNull()
        .map((r) => r?.syncStatus);
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ohs_shield.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
