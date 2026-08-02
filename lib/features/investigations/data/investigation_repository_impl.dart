// path: lib/features/investigations/data/investigation_repository_impl.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/investigations/data/investigation_dto.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/repositories/investigation_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _entity = 'investigation';

final class InvestigationRepositoryImpl extends BaseRepository implements InvestigationRepository {
  InvestigationRepositoryImpl(this._client, this._offline, this._db, LoggerService logger,
      {Uuid uuid = const Uuid(),})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<Investigation>>> list({String? hazardId, String? incidentId}) {
    return run(() async {
      final byId = <String, Investigation>{};
      try {
        var q = _client.from('investigations').select();
        if (hazardId != null) q = q.eq('hazard_id', hazardId);
        if (incidentId != null) q = q.eq('incident_id', incidentId);
        final rows = await q.order('opened_at', ascending: false);
        for (final r in rows) {
          final i = InvestigationDto.fromJson(r).toEntity();
          byId[i.id] = i;
        }
      } catch (e, s) {
        logger.warn('investigation list: server unavailable, using cache', e, s);
      }
      for (final c in await _db.cachedByType(_entity)) {
        try {
          final i = InvestigationDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
          if ((hazardId == null || i.hazardId == hazardId) && (incidentId == null || i.incidentId == incidentId)) {
            byId[i.id] = i;
          }
        } catch (_) {}
      }
      return byId.values.toList()..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    }, context: 'list',);
  }

  @override
  Future<Result<Investigation>> getInvestigation(String id) {
    return run(() async {
      try {
        final row = await _client.from('investigations').select().eq('id', id).maybeSingle();
        if (row != null) return InvestigationDto.fromJson(row).toEntity();
      } catch (e, s) {
        logger.warn('getInvestigation: server unavailable, using cache', e, s);
      }
      final cached = await _db.cachedByType(_entity);
      final match = cached.where((c) => c.entityId == id);
      if (match.isNotEmpty) {
        return InvestigationDto.fromJson(jsonDecode(match.first.data) as Map<String, dynamic>).toEntity();
      }
      throw StateError('Investigation not found: $id');
    }, context: 'getInvestigation',);
  }

  @override
  Future<Result<Investigation>> create({
    required String companyId,
    required String investigatorId,
    String? hazardId,
    String? incidentId,
    String? siteId,
  }) async {
    if ((hazardId == null) == (incidentId == null)) {
      return Future.value(const Err(ValidationFailure('An investigation must originate from exactly one hazard or incident.')));
    }
    final id = _uuid.v4();
    final data = <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'site_id': siteId,
      'hazard_id': hazardId,
      'incident_id': incidentId,
      'investigator_id': investigatorId,
      'status': 'open',
      'analysis': InvestigationAnalysis.empty().toJson(),
      'opened_at': DateTime.now().toIso8601String(),
      'version': 0,
    };
    try {
      await _offline.enqueueCreate(entityType: _entity, entityId: id, data: data, companyId: companyId, userId: investigatorId);
      return Ok(InvestigationDto.fromJson(data).toEntity());
    } catch (e, s) {
      logger.error('create investigation enqueue failed', e, s);
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
    }, context: 'update',);
  }

  @override
  Future<Result<String>> generateCapa({
    required String investigationId,
    required String companyId,
    required String description,
    required String priority,
    String? siteId,
  }) {
    return run(() async {
      final id = _uuid.v4();
      await _client.from('corrective_actions').insert({
        'id': id, 'company_id': companyId, 'site_id': siteId, 'investigation_id': investigationId,
        'description': description, 'priority': priority, 'status': 'created',
      });
      return id;
    }, context: 'generateCapa',);
  }
}
