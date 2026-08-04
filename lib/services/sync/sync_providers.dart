// path: lib/services/sync/sync_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:ohs_shield_tracker/services/sync/sync_engine.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';

/// DI + lifecycle wiring for the offline sync subsystem.

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final offlineMutationServiceProvider = Provider<OfflineMutationService>((ref) {
  return OfflineMutationService(
    ref.watch(appDatabaseProvider),
    // Drain the outbox as soon as a mutation is queued (no dependency cycle:
    // the engine does not depend on this service).
    onEnqueued: () => unawaited(ref.read(syncEngineProvider).drain()),
  );
});

/// Creates the engine and starts auto-sync bound to connectivity.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    client: ref.watch(supabaseClientProvider),
    logger: ref.watch(loggerProvider),
  );
  final connectivity = ref.watch(connectivityStatusProvider.stream);
  engine.start(connectivity);
  ref.onDispose(engine.dispose);
  return engine;
});

/// Reactive per-record sync status for the UI badge (Prompt 3 §9.4).
final recordSyncStatusProvider =
    StreamProvider.family<SyncStatus, ({String type, String id})>((ref, key) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRecordStatus(key.type, key.id).map(SyncStatus.fromName);
});

/// Count of not-yet-synced (pending + failed) records, for the global offline banner.
final pendingSyncCountProvider = FutureProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).pendingCount();
});
