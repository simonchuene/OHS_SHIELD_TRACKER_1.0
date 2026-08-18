// path: lib/services/sync/sync_engine.dart
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/services/sync/conflict_resolver.dart';
import 'package:ohs_shield_tracker/services/sync/retry_policy.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drains the local outbox against Supabase when connectivity is available.
/// Sequential/FIFO to preserve causal order (e.g. create before its updates).
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required SupabaseClient client,
    required LoggerService logger,
    this.resolver = const ConflictResolver(),
    this.retry = const RetryPolicy(),
  })  : _db = db,
        _client = client,
        _logger = logger;

  final AppDatabase _db;
  final SupabaseClient _client;
  final LoggerService _logger;
  final ConflictResolver resolver;
  final RetryPolicy retry;

  StreamSubscription<bool>? _connSub;
  bool _running = false;

  /// Begin auto-syncing: drain now (in case we start online) and on every
  /// transition to online thereafter.
  void start(Stream<bool> connectivity) {
    _connSub = connectivity.listen((online) {
      if (online) unawaited(drain());
    });
    unawaited(drain()); // initial attempt at launch
  }

  Future<void> dispose() async => _connSub?.cancel();

  /// User-initiated retry (pull-to-refresh / tapping a failed badge): re-arm
  /// failed entries and drain.
  Future<void> syncNow() async {
    await (_db.update(_db.syncQueueEntries)..where((t) => t.status.equals('failed')))
        .write(SyncQueueEntriesCompanion(
      status: const Value('pending'),
      nextAttemptAt: Value(DateTime.now()),
    ),);
    await drain();
  }

  Future<void> drain() async {
    if (_running) return; // single drain at a time
    _running = true;
    try {
      // Scoped to the signed-in user: entries are pushed under the current
      // session, so another user's queued mutation could only be sent with the
      // wrong identity.
      final due = await _db.dueEntries(DateTime.now(), userId: _client.auth.currentUser?.id);
      for (final entry in due) {
        await _process(entry);
      }
    } catch (e, s) {
      _logger.error('Sync drain failed', e, s);
    } finally {
      _running = false;
    }
  }

  Future<void> _process(SyncQueueEntry entry) async {
    await _db.updateEntry(entry.id, const SyncQueueEntriesCompanion(status: Value('syncing')));
    await _db.setRecordStatus(entry.entityType, entry.entityId, SyncStatus.syncing.name);

    final table = SyncEntity.tableFor(entry.entityType);
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

    try {
      switch (SyncOperation.values.byName(entry.operation)) {
        case SyncOperation.insert:
          await _insert(table, entry, payload);
        case SyncOperation.update:
          await _update(table, entry, payload);
        case SyncOperation.delete:
          await _delete(table, entry);
      }
      await _db.deleteEntry(entry.id);
    } on PostgrestException catch (e, s) {
      await _handlePostgrestError(entry, e, s);
    } catch (e, s) {
      // Network/timeout/unknown -> retryable.
      await _scheduleRetryOrFail(entry, e.toString(), s, retryable: true);
    }
  }

  Future<void> _insert(String table, SyncQueueEntry entry, Map<String, dynamic> payload) async {
    try {
      final rows = await _client.from(table).insert(payload).select();
      await _reconcile(entry, rows.first);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Already inserted on a prior attempt — idempotent success.
        final rows = await _client.from(table).select().eq('id', entry.entityId);
        if (rows.isNotEmpty) {
          await _reconcile(entry, rows.first);
          return;
        }
      }
      rethrow;
    }
  }

  Future<void> _update(String table, SyncQueueEntry entry, Map<String, dynamic> changed) async {
    final serverRows = await _client.from(table).select().eq('id', entry.entityId);
    final serverRow = serverRows.isEmpty ? null : serverRows.first;

    final resolution = resolver.resolveUpdate(
      entityType: entry.entityType,
      changedFields: changed,
      baseVersion: entry.baseVersion,
      serverRow: serverRow,
      localUpdatedAt: entry.updatedAt,
    );

    switch (resolution) {
      case ApplyLocal(:final fields):
        final rows = await _client.from(table).update(fields).eq('id', entry.entityId).select();
        if (rows.isEmpty) {
          // RLS filtered the row on read-back -> treat as permission issue.
          throw const PostgrestException(message: 'No row returned after update', code: '42501');
        }
        await _reconcile(entry, rows.first);
        _logger.info('Sync update applied (${entry.entityType}/${entry.entityId})');
      case AcceptServer(:final serverRow):
        await _reconcile(entry, serverRow);
        _logger.warn('LWW conflict: server won (${entry.entityType}/${entry.entityId})');
      case Unresolvable(:final reason):
        await _scheduleRetryOrFail(entry, reason, StackTrace.current, retryable: false);
    }
  }

  Future<void> _delete(String table, SyncQueueEntry entry) async {
    await _client.from(table).delete().eq('id', entry.entityId);
    await (_db.delete(_db.cachedRecords)
          ..where((t) =>
              t.entityType.equals(entry.entityType) & t.entityId.equals(entry.entityId),))
        .go();
  }

  /// Refresh the local cache from the authoritative server row and mark synced.
  Future<void> _reconcile(SyncQueueEntry entry, Map<String, dynamic> serverRow) async {
    await _db.upsertCache(CachedRecordsCompanion(
      entityType: Value(entry.entityType),
      entityId: Value(entry.entityId),
      data: Value(jsonEncode(serverRow)),
      version: Value((serverRow['version'] as num?)?.toInt() ?? 0),
      syncStatus: Value(SyncStatus.synced.name),
      updatedAt: Value(DateTime.now()),
    ),);
  }

  Future<void> _handlePostgrestError(
      SyncQueueEntry entry, PostgrestException e, StackTrace s,) async {
    // 42501 = RLS/permission denial; 4xx validation -> non-retryable.
    final nonRetryable = e.code == '42501' ||
        (int.tryParse(e.code ?? '') != null &&
            int.parse(e.code!) >= 400 &&
            int.parse(e.code!) < 500 &&
            e.code != '429');
    await _scheduleRetryOrFail(entry, '${e.code}: ${e.message}', s, retryable: !nonRetryable);
  }

  Future<void> _scheduleRetryOrFail(
    SyncQueueEntry entry,
    String error,
    StackTrace s, {
    required bool retryable,
  }) async {
    final nextAttempts = entry.attempts + 1;
    if (!retryable || !retry.hasAttemptsLeft(nextAttempts)) {
      await _db.updateEntry(
        entry.id,
        SyncQueueEntriesCompanion(
          status: const Value('failed'),
          attempts: Value(nextAttempts),
          lastError: Value(error),
        ),
      );
      await _db.setRecordStatus(entry.entityType, entry.entityId, SyncStatus.failed.name);
      _logger.error('Sync failed (${entry.entityType}/${entry.entityId}): $error');
    } else {
      final delay = retry.delayForAttempt(nextAttempts);
      await _db.updateEntry(
        entry.id,
        SyncQueueEntriesCompanion(
          status: const Value('pending'),
          attempts: Value(nextAttempts),
          nextAttemptAt: Value(DateTime.now().add(delay)),
          lastError: Value(error),
        ),
      );
      await _db.setRecordStatus(entry.entityType, entry.entityId, SyncStatus.pending.name);
      _logger.warn('Sync retry #$nextAttempts in ${delay.inSeconds}s '
          '(${entry.entityType}/${entry.entityId})');
    }
  }
}
