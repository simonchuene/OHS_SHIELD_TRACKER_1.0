// path: lib/features/capa/data/capa_repository_impl.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/capa/data/capa_dto.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/capa/domain/repositories/capa_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _entity = 'corrective_action';

final class CapaRepositoryImpl extends BaseRepository implements CapaRepository {
  CapaRepositoryImpl(this._client, this._offline, this._db, LoggerService logger, {Uuid uuid = const Uuid()})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<CorrectiveAction>>> list(CapaFilter filter, {String? currentUserId}) {
    return run(() async {
      final byId = <String, CorrectiveAction>{};
      try {
        var q = _client.from('corrective_actions').select();
        if (filter.status != null) q = q.eq('status', filter.status!.dbValue);
        if (filter.priority != null) q = q.eq('priority', filter.priority!.dbValue);
        if (filter.mineOnly && currentUserId != null) q = q.eq('owner_id', currentUserId);
        final rows = await q.order('created_at', ascending: false);
        for (final r in rows) {
          final c = CapaDto.fromJson(r).toEntity();
          byId[c.id] = c;
        }
      } catch (e, s) {
        logger.warn('capa list: server unavailable, using cache', e, s);
      }
      for (final c in await _db.cachedByType(_entity)) {
        try {
          byId[c.entityId] = CapaDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
        } catch (_) {}
      }
      var list = byId.values.toList();
      if (filter.status != null) list = list.where((c) => c.status == filter.status).toList();
      if (filter.priority != null) list = list.where((c) => c.priority == filter.priority).toList();
      if (filter.mineOnly && currentUserId != null) list = list.where((c) => c.ownerId == currentUserId).toList();
      final q = filter.query?.trim().toLowerCase();
      if (q != null && q.isNotEmpty) list = list.where((c) => c.description.toLowerCase().contains(q)).toList();
      return list;
    }, context: 'listCapa',);
  }

  @override
  Future<Result<List<CorrectiveAction>>> listForHazard(String hazardId) {
    return run(() async {
      final byId = <String, CorrectiveAction>{};
      try {
        final rows = await _client
            .from('corrective_actions')
            .select()
            .eq('hazard_id', hazardId)
            .order('created_at', ascending: false);
        for (final r in rows) {
          final c = CapaDto.fromJson(r).toEntity();
          byId[c.id] = c;
        }
      } catch (e, s) {
        logger.warn('capa listForHazard: server unavailable, using cache', e, s);
      }
      // Merge locally-cached CAPAs for this hazard (offline-created/pending).
      for (final c in await _db.cachedByType(_entity)) {
        try {
          final capa = CapaDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
          if (capa.hazardId == hazardId) byId[capa.id] = capa;
        } catch (_) {}
      }
      // Open actions first (they gate hazard closure), then by description.
      final list = byId.values.toList()
        ..sort((a, b) {
          if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
          return a.description.toLowerCase().compareTo(b.description.toLowerCase());
        });
      return list;
    }, context: 'listCapaForHazard',);
  }

  @override
  Future<Result<CorrectiveAction>> get(String id) {
    return run(() async {
      final match = (await _db.cachedByType(_entity)).where((c) => c.entityId == id);
      final cached = match.isEmpty ? null : match.first;
      // An unsynced local write is the source of truth until it reconciles with
      // the server. Reading the server first here returned the pre-edit row, so a
      // status transition looked like nothing happened until a second tap (by
      // which point the first write had synced). Prefer the optimistic cache
      // while a mutation is still pending/syncing.
      if (cached != null &&
          (cached.syncStatus == SyncStatus.pending.name || cached.syncStatus == SyncStatus.syncing.name)) {
        return CapaDto.fromJson(jsonDecode(cached.data) as Map<String, dynamic>).toEntity();
      }
      try {
        final row = await _client.from('corrective_actions').select().eq('id', id).maybeSingle();
        if (row != null) return CapaDto.fromJson(row).toEntity();
      } catch (e, s) {
        logger.warn('getCapa: server unavailable, using cache', e, s);
      }
      if (cached != null) return CapaDto.fromJson(jsonDecode(cached.data) as Map<String, dynamic>).toEntity();
      throw StateError('CAPA not found: $id');
    }, context: 'getCapa',);
  }

  @override
  Future<Result<CorrectiveAction>> create({
    required String companyId,
    required String description,
    required CapaPriority priority,
    required CapaSourceRef source,
    String? siteId,
    String? ownerId,
    DateTime? dueDate,
    required String userId,
  }) async {
    if (!source.isValid) {
      return Future.value(const Err(ValidationFailure('A CAPA must link to exactly one source.')));
    }
    final id = _uuid.v4();
    final data = <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'site_id': siteId,
      'description': description,
      'priority': priority.dbValue,
      'owner_id': ownerId,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
      'status': ownerId != null ? CapaStatus.assigned.dbValue : CapaStatus.created.dbValue,
      'hazard_id': source.hazardId,
      'incident_id': source.incidentId,
      'investigation_id': source.investigationId,
      'inspection_item_id': source.inspectionItemId,
      'version': 0,
    };
    try {
      await _offline.enqueueCreate(entityType: _entity, entityId: id, data: data, companyId: companyId, userId: userId);
      return Ok(CapaDto.fromJson(data).toEntity());
    } catch (e, s) {
      logger.error('create capa enqueue failed', e, s);
      return const Err(CacheFailure());
    }
  }

  @override
  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) {
    return run(() async {
      await _offline.enqueueUpdate(entityType: _entity, entityId: id, changedFields: changes, baseVersion: baseVersion, companyId: companyId, userId: userId);
    }, context: 'updateCapa',);
  }
}
