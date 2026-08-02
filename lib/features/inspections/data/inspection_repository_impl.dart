// path: lib/features/inspections/data/inspection_repository_impl.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/inspections/data/inspection_dtos.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/checklist_templates.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/inspection_scoring.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/repositories/inspection_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _insp = 'inspection';
const _item = 'inspection_item';
const _graph = '*, inspection_items(*)';

final class InspectionRepositoryImpl extends BaseRepository implements InspectionRepository {
  InspectionRepositoryImpl(this._client, this._offline, this._db, LoggerService logger, {Uuid uuid = const Uuid()})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<Inspection>>> list() {
    return run(() async {
      final byId = <String, Inspection>{};
      try {
        final rows = await _client.from('inspections').select().order('created_at', ascending: false);
        for (final r in rows) {
          byId[r['id'] as String] = InspectionDto.fromJson(r).toEntity(overrideItems: const []);
        }
      } catch (e, s) {
        logger.warn('inspection list: server unavailable, using cache', e, s);
      }
      for (final c in await _db.cachedByType(_insp)) {
        try {
          byId[c.entityId] = InspectionDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity(overrideItems: const []);
        } catch (_) {}
      }
      return byId.values.toList()..sort((a, b) => (b.conductedAt ?? DateTime(0)).compareTo(a.conductedAt ?? DateTime(0)));
    }, context: 'listInspections',);
  }

  @override
  Future<Result<Inspection>> get(String id) {
    return run(() async {
      try {
        final row = await _client.from('inspections').select(_graph).eq('id', id).maybeSingle();
        if (row != null) return InspectionDto.fromJson(row).toEntity();
      } catch (e, s) {
        logger.warn('getInspection: server unavailable, using cache', e, s);
      }
      // Offline: rebuild from cached inspection + cached items.
      final inspCache = (await _db.cachedByType(_insp)).where((c) => c.entityId == id);
      if (inspCache.isEmpty) throw StateError('Inspection not found: $id');
      final items = <InspectionItem>[];
      for (final c in await _db.cachedByType(_item)) {
        try {
          final dto = InspectionItemDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>);
          if (dto.inspectionId == id) items.add(dto.toEntity());
        } catch (_) {}
      }
      return InspectionDto.fromJson(jsonDecode(inspCache.first.data) as Map<String, dynamic>).toEntity(overrideItems: items);
    }, context: 'getInspection',);
  }

  @override
  Future<Result<Inspection>> create({
    required InspectionType type,
    required String companyId,
    required String inspectorId,
    String? siteId,
    String? departmentId,
    DateTime? scheduledDate,
  }) async {
    final id = _uuid.v4();
    final inspData = <String, dynamic>{
      'id': id, 'company_id': companyId, 'site_id': siteId, 'department_id': departmentId,
      'inspection_type': type.dbValue, 'inspector_id': inspectorId, 'status': 'in_progress',
      'scheduled_date': scheduledDate?.toIso8601String().substring(0, 10),
      'conducted_at': DateTime.now().toIso8601String(), 'version': 0,
    };
    try {
      // Inspection first, then items (FIFO preserves the FK order on sync).
      await _offline.enqueueCreate(entityType: _insp, entityId: id, data: inspData, companyId: companyId, userId: inspectorId);
      final prompts = ChecklistTemplates.forType(type);
      final items = <InspectionItem>[];
      for (var i = 0; i < prompts.length; i++) {
        final itemId = _uuid.v4();
        final itemData = <String, dynamic>{
          'id': itemId, 'company_id': companyId, 'inspection_id': id, 'position': i, 'prompt': prompts[i], 'version': 0,
        };
        await _offline.enqueueCreate(entityType: _item, entityId: itemId, data: itemData, companyId: companyId, userId: inspectorId);
        items.add(InspectionItemDto.fromJson(itemData).toEntity());
      }
      return Ok(InspectionDto.fromJson(inspData).toEntity(overrideItems: items));
    } catch (e, s) {
      logger.error('create inspection enqueue failed', e, s);
      return const Err(CacheFailure());
    }
  }

  @override
  Future<Result<void>> setItemResult({
    required String itemId,
    required InspectionItemResult result,
    String? notes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) {
    return run(() async {
      await _offline.enqueueUpdate(
        entityType: _item, entityId: itemId,
        changedFields: {'result': result.dbValue, if (notes != null) 'notes': notes},
        baseVersion: baseVersion, companyId: companyId, userId: userId,
      );
    }, context: 'setItemResult',);
  }

  @override
  Future<Result<Inspection>> submit(Inspection inspection) {
    return run(() async {
      // Work from the authoritative server copy (offline edits have synced by now).
      final serverRow = await _client.from('inspections').select(_graph).eq('id', inspection.id).single();
      final fresh = InspectionDto.fromJson(serverRow).toEntity();

      for (final item in fresh.items.where((i) => i.isFail && !i.generated)) {
        final res = await _client.functions.invoke('inspection-item-fail', body: {'inspectionItemId': item.id});
        final data = res.data;
        if (res.status >= 400 || (data is Map && data['error'] != null)) {
          throw StateError((data is Map ? data['error']?.toString() : null) ?? 'Auto-generation failed for an item');
        }
      }

      final score = InspectionScoring.scorePercent(fresh.items);
      final updated = await _client.from('inspections').update({
        'status': 'submitted', 'score': score, 'conducted_at': DateTime.now().toIso8601String(),
      }).eq('id', inspection.id).select(_graph).single();
      return InspectionDto.fromJson(updated).toEntity();
    }, context: 'submitInspection',);
  }
}
