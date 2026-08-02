// path: lib/features/risk/data/risk_assessment_repository_impl.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/risk/data/risk_assessment_dto.dart';
import 'package:ohs_shield_tracker/features/risk/domain/entities/risk_assessment.dart';
import 'package:ohs_shield_tracker/features/risk/domain/repositories/risk_assessment_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:ohs_shield_tracker/services/sync/offline_mutation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _entity = 'risk_assessment';

final class RiskAssessmentRepositoryImpl extends BaseRepository implements RiskAssessmentRepository {
  RiskAssessmentRepositoryImpl(this._client, this._offline, this._db, LoggerService logger,
      {Uuid uuid = const Uuid(),})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final OfflineMutationService _offline;
  final AppDatabase _db;
  final Uuid _uuid;

  @override
  Future<Result<List<RiskAssessment>>> listForHazard(String hazardId) {
    return run(() async {
      final byId = <String, RiskAssessment>{};
      try {
        final rows = await _client.from('risk_assessments').select().eq('hazard_id', hazardId).order('assessed_at', ascending: false);
        for (final r in rows) {
          final a = RiskAssessmentDto.fromJson(r).toEntity();
          byId[a.id] = a;
        }
      } catch (e, s) {
        logger.warn('risk list: server unavailable, using cache', e, s);
      }
      for (final c in await _db.cachedByType(_entity)) {
        try {
          final a = RiskAssessmentDto.fromJson(jsonDecode(c.data) as Map<String, dynamic>).toEntity();
          if (a.hazardId == hazardId) byId[a.id] = a;
        } catch (_) {}
      }
      return byId.values.toList()..sort((a, b) => b.assessedAt.compareTo(a.assessedAt));
    }, context: 'listForHazard',);
  }

  @override
  Future<Result<RiskAssessment?>> latestForHazard(String hazardId) async {
    final res = await listForHazard(hazardId);
    return res.map((list) => list.isEmpty ? null : list.first);
  }

  @override
  Future<Result<RiskAssessment>> saveAssessment(
    SaveRiskParams params, {
    required String companyId,
    required String assessorId,
  }) async {
    final id = _uuid.v4();
    // NB: risk_score / risk_band are GENERATED — never included in the payload.
    final data = <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'hazard_id': params.hazardId,
      'likelihood': params.likelihood,
      'severity': params.severity,
      'current_controls': params.currentControls,
      'required_controls': params.requiredControls,
      'residual_likelihood': params.residualLikelihood,
      'residual_severity': params.residualSeverity,
      'assessor_id': assessorId,
      'review_date': params.reviewDate?.toIso8601String(),
      'assessed_at': DateTime.now().toIso8601String(),
      'version': 0,
    };
    try {
      await _offline.enqueueCreate(entityType: _entity, entityId: id, data: data, companyId: companyId, userId: assessorId);
      return Ok(RiskAssessmentDto.fromJson(data).toEntity());
    } catch (e, s) {
      logger.error('saveAssessment enqueue failed', e, s);
      return const Err(CacheFailure());
    }
  }
}
