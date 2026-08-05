// path: lib/features/hazards/data/hazard_repository_impl.dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/hazards/data/hazard_dto.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/repositories/hazard_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final class HazardRepositoryImpl extends BaseRepository implements HazardRepository {
  HazardRepositoryImpl(this._client, this._offline, this._db, LoggerService logger,
      {Uuid uuid = const Uuid(),})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<Hazard>>> listHazards(HazardFilter filter, {String? currentUserId}) {
    return run(() async {
      final byId = <String, Hazard>{};

      // Server (RLS-scoped). Fall back to cache-only when offline.
      try {
        var q = _client.from('hazards').select();
        if (filter.status != null) q = q.eq('status', filter.status!.dbValue);
        if (filter.riskLevel != null) {
          // A risk filter means "this band or more severe" so the dashboard's
          // "High Risk" KPI (which counts high AND critical) matches the list it
          // opens — an exact-band match would hide Critical hazards.
          q = q.inFilter('risk_level', _bandsAtLeast(filter.riskLevel!));
        }
        if (filter.siteId != null) q = q.eq('site_id', filter.siteId!);
        if (filter.mineOnly && currentUserId != null) q = q.eq('reporter_id', currentUserId);
        // Bound the request so a slow/dead network fails fast into the cache
        // fallback below, instead of hanging and leaving the list stuck.
        final rows = await q
            .order('reported_at', ascending: false)
            .timeout(const Duration(seconds: 8));
        for (final r in rows) {
          final h = HazardDto.fromJson(r).toEntity();
          byId[h.id] = h;
          // Cache-on-read: persist the server row so a later offline/failed
          // fetch falls back to last-known data instead of showing an empty list.
          await _db.upsertCache(CachedRecordsCompanion(
            entityType: Value(SyncEntity.hazard),
            entityId: Value(h.id),
            data: Value(jsonEncode(r)),
            version: Value((r['version'] as num?)?.toInt() ?? h.version),
            syncStatus: Value(SyncStatus.synced.name),
            updatedAt: Value(DateTime.now()),
          ),);
        }
      } catch (e, s) {
        logger.warn('Hazard list: server unavailable, using cache', e, s);
      }

      // Merge locally-cached rows (offline-created/pending override; synced dups skip).
      for (final c in await _db.cachedByType(SyncEntity.hazard)) {
        if (c.syncStatus == SyncStatus.synced.name && byId.containsKey(c.entityId)) continue;
        try {
          byId[c.entityId] = HazardDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
        } catch (_) {
          // Skip malformed cache rows.
        }
      }

      var list = byId.values.toList()..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
      // Re-apply filters to cover cached items the server query didn't see.
      if (filter.status != null) list = list.where((h) => h.status == filter.status).toList();
      if (filter.riskLevel != null) {
        final floor = filter.riskLevel!.index;
        list = list.where((h) => (h.riskLevel?.index ?? -1) >= floor).toList();
      }
      if (filter.mineOnly && currentUserId != null) {
        list = list.where((h) => h.reporterId == currentUserId).toList();
      }
      final query = filter.query?.trim().toLowerCase();
      if (query != null && query.isNotEmpty) {
        list = list
            .where((h) =>
                h.title.toLowerCase().contains(query) ||
                (h.description?.toLowerCase().contains(query) ?? false),)
            .toList();
      }
      return list;
    }, context: 'listHazards',);
  }

  /// The db values for [floor] and every more-severe band (low<medium<high<critical).
  List<String> _bandsAtLeast(RiskBand floor) =>
      RiskBand.values.where((b) => b.index >= floor.index).map((b) => b.dbValue).toList();

  @override
  Future<Result<Hazard>> getHazard(String id) {
    return run(() async {
      final match = (await _db.cachedByType(SyncEntity.hazard)).where((c) => c.entityId == id);
      final cached = match.isEmpty ? null : match.first;
      // Prefer an unsynced local write over the server so a status transition
      // shows immediately instead of appearing to need a second tap (the server
      // still returns the pre-edit row until the outbox drains).
      if (cached != null &&
          (cached.syncStatus == SyncStatus.pending.name || cached.syncStatus == SyncStatus.syncing.name)) {
        return HazardDto.fromJson(jsonDecode(cached.data) as Map<String, dynamic>).toEntity();
      }
      try {
        final row = await _client.from('hazards').select().eq('id', id).maybeSingle();
        if (row != null) return HazardDto.fromJson(row).toEntity();
      } catch (e, s) {
        logger.warn('getHazard: server unavailable, using cache', e, s);
      }
      if (cached != null) {
        return HazardDto.fromJson(jsonDecode(cached.data) as Map<String, dynamic>).toEntity();
      }
      throw StateError('Hazard not found: $id');
    }, context: 'getHazard',);
  }

  @override
  Future<Result<Hazard>> reportHazard(
    ReportHazardParams params, {
    required String companyId,
    required String reporterId,
  }) async {
    final id = _uuid.v4();
    final status = params.submitNow ? HazardStatus.submitted : HazardStatus.draft;
    final data = <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'site_id': params.siteId,
      'department_id': params.departmentId,
      'title': params.title,
      'description': params.description,
      'category': params.category.dbValue,
      'status': status.dbValue,
      'reporter_id': reporterId,
      'latitude': params.latitude,
      'longitude': params.longitude,
      'location_text': params.locationText,
      'reported_at': DateTime.now().toIso8601String(),
      'version': 0,
    };
    try {
      await _offline.enqueueCreate(
        entityType: SyncEntity.hazard,
        entityId: id,
        data: data,
        companyId: companyId,
        userId: reporterId,
      );
      return Ok(HazardDto.fromJson(data).toEntity());
    } catch (e, s) {
      logger.error('reportHazard enqueue failed', e, s);
      return const Err(CacheFailure());
    }
  }

  @override
  Future<Result<void>> updateHazard({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) {
    return run(() async {
      await _offline.enqueueUpdate(
        entityType: SyncEntity.hazard,
        entityId: id,
        changedFields: changes,
        baseVersion: baseVersion,
        companyId: companyId,
        userId: userId,
      );
    }, context: 'updateHazard',);
  }
}
