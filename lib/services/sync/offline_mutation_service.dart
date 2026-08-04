// path: lib/services/sync/offline_mutation_service.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:uuid/uuid.dart';

/// Offline queueing hooks consumed by the Hazard, Incident, Inspection, and
/// CAPA repositories (Prompts 7–12). Every offline-capable mutation:
///   1) writes the local cache optimistically (status = pending), and
///   2) appends a `sync_queue` entry,
/// then returns immediately. The [SyncEngine] drains the queue when online.
class OfflineMutationService {
  OfflineMutationService(this._db, {this.onEnqueued, Uuid uuid = const Uuid()})
      : _uuid = uuid;

  final AppDatabase _db;
  final Uuid _uuid;

  /// Called right after an entry is appended to the outbox. Wired to nudge the
  /// [SyncEngine] to drain immediately (online), instead of leaving the change
  /// "pending" until the next connectivity event or app launch.
  final void Function()? onEnqueued;

  /// Queue a create. Client mints [entityId] (UUID PKs, D-schema-1) so the row
  /// is usable offline and stable after sync.
  Future<String> enqueueCreate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> data,
    required String companyId,
    required String userId,
  }) async {
    await _db.upsertCache(CachedRecordsCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      data: Value(jsonEncode(data)),
      version: const Value(0),
      syncStatus: Value(SyncStatus.pending.name),
      updatedAt: Value(DateTime.now()),
    ),);
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.insert,
      payload: data,
      baseVersion: null,
      companyId: companyId,
      userId: userId,
    );
  }

  /// Queue an update carrying only the changed fields (diff) + the [baseVersion]
  /// the user edited from — this drives conflict detection (D4).
  Future<String> enqueueUpdate({
    required String entityType,
    required String entityId,
    required Map<String, dynamic> changedFields,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) async {
    final existing = await _cache(entityType, entityId);
    final merged = {...?existing, ...changedFields};
    await _db.upsertCache(CachedRecordsCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      data: Value(jsonEncode(merged)),
      version: Value(baseVersion),
      syncStatus: Value(SyncStatus.pending.name),
      updatedAt: Value(DateTime.now()),
    ),);
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.update,
      payload: changedFields,
      baseVersion: baseVersion,
      companyId: companyId,
      userId: userId,
    );
  }

  Future<String> enqueueDelete({
    required String entityType,
    required String entityId,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) async {
    await _db.setRecordStatus(entityType, entityId, SyncStatus.pending.name);
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.delete,
      payload: const {},
      baseVersion: baseVersion,
      companyId: companyId,
      userId: userId,
    );
  }

  Future<String> _enqueue({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    required int? baseVersion,
    required String companyId,
    required String userId,
  }) async {
    final id = _uuid.v4();
    await _db.enqueue(SyncQueueEntriesCompanion(
      id: Value(id),
      companyId: Value(companyId),
      userId: Value(userId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation.name),
      payload: Value(jsonEncode(payload)),
      baseVersion: Value(baseVersion),
      status: Value(SyncStatus.pending.name),
    ),);
    onEnqueued?.call();
    return id;
  }

  Future<Map<String, dynamic>?> _cache(String type, String id) async {
    final row = await (_db.select(_db.cachedRecords)
          ..where((t) => t.entityType.equals(type) & t.entityId.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.data) as Map<String, dynamic>;
  }
}
