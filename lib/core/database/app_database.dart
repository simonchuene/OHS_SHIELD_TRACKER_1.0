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

@DriftDatabase(tables: [SyncQueueEntries, CachedRecords, PendingUploads, ReportHistoryEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(pendingUploads);
          if (from < 3) await m.createTable(reportHistoryEntries);
        },
      );

  // --- Outbox -------------------------------------------------------------

  Future<void> enqueue(SyncQueueEntriesCompanion entry) =>
      into(syncQueueEntries).insert(entry);

  /// Pending entries whose backoff window has elapsed, oldest first (FIFO).
  Future<List<SyncQueueEntry>> dueEntries(DateTime now) {
    return (select(syncQueueEntries)
          ..where((t) =>
              t.status.equals('pending') &
              (t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(now)),)
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
