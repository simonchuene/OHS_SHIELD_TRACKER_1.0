// path: lib/features/incidents/data/incident_repository_impl.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/incidents/data/incident_dto.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_filter.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/repositories/incident_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _entity = 'incident';

final class IncidentRepositoryImpl extends BaseRepository implements IncidentRepository {
  IncidentRepositoryImpl(this._client, this._offline, this._db, LoggerService logger,
      {Uuid uuid = const Uuid(),})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<Incident>>> listIncidents(IncidentFilter filter, {String? currentUserId}) {
    return run(() async {
      final byId = <String, Incident>{};
      try {
        var q = _client.from('incidents').select();
        if (filter.status != null) q = q.eq('status', filter.status!.dbValue);
        if (filter.severity != null) q = q.eq('severity', filter.severity!.dbValue);
        if (filter.type != null) q = q.eq('incident_type', filter.type!.dbValue);
        if (filter.siteId != null) q = q.eq('site_id', filter.siteId!);
        if (filter.mineOnly && currentUserId != null) q = q.eq('reporter_id', currentUserId);
        final rows = await q.order('occurred_at', ascending: false);
        for (final r in rows) {
          final i = IncidentDto.fromJson(r).toEntity();
          byId[i.id] = i;
        }
      } catch (e, s) {
        logger.warn('Incident list: server unavailable, using cache', e, s);
      }
      for (final c in await _db.cachedByType(_entity)) {
        try {
          byId[c.entityId] = IncidentDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
        } catch (_) {}
      }
      var list = byId.values.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final query = filter.query?.trim().toLowerCase();
      if (query != null && query.isNotEmpty) {
        list = list
            .where((i) => (i.description?.toLowerCase().contains(query) ?? false) || i.type.label.toLowerCase().contains(query))
            .toList();
      }
      return list;
    }, context: 'listIncidents',);
  }

  @override
  Future<Result<Incident>> getIncident(String id) {
    return run(() async {
      try {
        final row = await _client.from('incidents').select().eq('id', id).maybeSingle();
        if (row != null) return IncidentDto.fromJson(row).toEntity();
      } catch (e, s) {
        logger.warn('getIncident: server unavailable, using cache', e, s);
      }
      final cached = await _db.cachedByType(_entity);
      final match = cached.where((c) => c.entityId == id);
      if (match.isNotEmpty) {
        return IncidentDto.fromJson(jsonDecode(match.first.data) as Map<String, dynamic>).toEntity();
      }
      throw StateError('Incident not found: $id');
    }, context: 'getIncident',);
  }

  @override
  Future<Result<Incident>> reportIncident(
    ReportIncidentParams params, {
    required String companyId,
    required String reporterId,
  }) async {
    final id = _uuid.v4();
    final data = <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'site_id': params.siteId,
      'department_id': params.departmentId,
      'incident_type': params.type.dbValue,
      'severity': params.severity.dbValue,
      'status': IncidentStatus.reported.dbValue,
      'occurred_at': params.occurredAt.toIso8601String(),
      'location_text': params.locationText,
      'latitude': params.latitude,
      'longitude': params.longitude,
      'description': params.description,
      'witnesses': [for (final w in params.witnesses) w.toJson()],
      'source_hazard_id': params.sourceHazardId,
      'reporter_id': reporterId,
      'version': 0,
    };
    try {
      await _offline.enqueueCreate(
          entityType: _entity, entityId: id, data: data, companyId: companyId, userId: reporterId,);
      return Ok(IncidentDto.fromJson(data).toEntity());
    } catch (e, s) {
      logger.error('reportIncident enqueue failed', e, s);
      return const Err(CacheFailure());
    }
  }

  @override
  Future<Result<void>> updateIncident({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) {
    return run(() async {
      await _offline.enqueueUpdate(
          entityType: _entity, entityId: id, changedFields: changes,
          baseVersion: baseVersion, companyId: companyId, userId: userId,);
    }, context: 'updateIncident',);
  }

  @override
  Future<Result<void>> linkToHazard({required String incidentId, required String hazardId}) {
    return run(() async {
      await _client.from('incidents').update({'source_hazard_id': hazardId}).eq('id', incidentId);
      await _client.from('hazards').update({'source_incident_id': incidentId}).eq('id', hazardId);
    }, context: 'linkToHazard',);
  }

  @override
  Future<Result<String>> generateInvestigation({
    required String incidentId,
    required String companyId,
    required String investigatorId,
    String? siteId,
  }) {
    return run(() async {
      final id = _uuid.v4();
      await _client.from('investigations').insert({
        'id': id, 'company_id': companyId, 'site_id': siteId, 'incident_id': incidentId,
        'investigator_id': investigatorId, 'status': 'open',
      });
      return id;
    }, context: 'generateInvestigation',);
  }

  @override
  Future<Result<String>> generateCapa({
    required String incidentId,
    required String companyId,
    required String description,
    required String priority,
    String? siteId,
    String? ownerId,
    DateTime? dueDate,
  }) {
    return run(() async {
      final id = _uuid.v4();
      await _client.from('corrective_actions').insert({
        'id': id, 'company_id': companyId, 'site_id': siteId, 'incident_id': incidentId,
        'description': description, 'priority': priority, 'status': 'created',
        'owner_id': ownerId, 'due_date': dueDate?.toIso8601String(),
      });
      return id;
    }, context: 'generateCapa',);
  }
}
