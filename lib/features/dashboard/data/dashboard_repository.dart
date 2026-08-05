// path: lib/features/dashboard/data/dashboard_repository.dart
import 'dart:convert';

import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_data.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_scope.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/safety_score.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cacheEntity = 'dashboard';

/// Computes role-scoped dashboard aggregates from RLS-scoped queries (the
/// own→dept→site→enterprise visibility ladder means the same queries return
/// role-appropriate data). Caches the last snapshot for offline. A server-side
/// `dashboard-aggregates` Edge Function / materialized view is a deferred
/// perf optimisation (DEV) — client aggregation is fine at 10–50-user scale.
class DashboardRepository {
  DashboardRepository(this._client, this._db, this._logger);
  final SupabaseClient _client;
  final AppDatabase _db;
  final LoggerService _logger;

  Future<Result<DashboardData>> load({required AppRole? role, required String userId}) async {
    try {
      final now = DateTime.now();
      final since30 = now.subtract(const Duration(days: 30));

      final hazards = await _client.from('hazards').select('id,status,risk_level,department_id');
      final capas = await _client.from('corrective_actions').select('id,status,due_date');
      final incidents = await _client.from('incidents').select('id,severity,incident_type,occurred_at');
      final inspections = await _client.from('inspections').select('id,status');
      final departments = await _client.from('departments').select('id,name');

      bool open(String? s) => s != 'closed' && s != null;
      final deptName = {for (final d in departments) d['id'] as String: d['name'] as String};

      final openHazards = hazards.where((h) => open(h['status'] as String?)).length;
      final highRisk = hazards.where((h) => open(h['status'] as String?) && (h['risk_level'] == 'high' || h['risk_level'] == 'critical')).length;

      final openCapas = capas.where((c) => open(c['status'] as String?)).length;
      final overdueCapas = capas.where((c) {
        if (!open(c['status'] as String?)) return false;
        final due = c['due_date'] != null ? DateTime.tryParse(c['due_date'] as String) : null;
        return CorrectiveAction.isPastDue(due, now: now);
      }).length;
      final closedCapas = capas.where((c) => c['status'] == 'closed').length;
      final capaClosureRate = capas.isEmpty ? 0.0 : closedCapas / capas.length;

      final inc30 = incidents.where((i) {
        final at = DateTime.tryParse(i['occurred_at'] as String? ?? '');
        return at != null && at.isAfter(since30);
      }).toList();
      final incidents30d = inc30.length;
      final nearMisses30d = inc30.where((i) => i['incident_type'] == 'near_miss').length;
      final seriousIncidents30d = inc30.where((i) => i['severity'] == 'serious' || i['severity'] == 'critical').length;

      final doneInsp = inspections.where((i) => i['status'] == 'submitted' || i['status'] == 'closed').length;
      final inspectionCompletionRate = inspections.isEmpty ? 0.0 : doneInsp / inspections.length;

      // Department risk ranking (open high/critical hazards), top 5.
      final deptCounts = <String, int>{};
      for (final h in hazards) {
        if (open(h['status'] as String?) && (h['risk_level'] == 'high' || h['risk_level'] == 'critical')) {
          final d = h['department_id'] as String?;
          final label = d == null ? 'Unassigned' : (deptName[d] ?? 'Department');
          deptCounts[label] = (deptCounts[label] ?? 0) + 1;
        }
      }
      final ranking = deptCounts.entries.map((e) => DeptRisk(e.key, e.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      // Incident trend: last 6 weeks by occurred_at.
      final trend = <TrendPoint>[];
      for (var w = 5; w >= 0; w--) {
        final start = now.subtract(Duration(days: (w + 1) * 7));
        final end = now.subtract(Duration(days: w * 7));
        final n = incidents.where((i) {
          final at = DateTime.tryParse(i['occurred_at'] as String? ?? '');
          return at != null && at.isAfter(start) && !at.isAfter(end);
        }).length;
        trend.add(TrendPoint('W-$w', n));
      }

      final kpi = KpiSet(
        openHazards: openHazards, highRiskHazards: highRisk, openCapas: openCapas,
        overdueCapas: overdueCapas, incidents30d: incidents30d, nearMisses30d: nearMisses30d,
        seriousIncidents30d: seriousIncidents30d, capaClosureRate: capaClosureRate,
        inspectionCompletionRate: inspectionCompletionRate,
      );

      final data = DashboardData(
        scopeLabel: DashboardScope.labelFor(role),
        safetyScore: SafetyScore.compute(highRiskHazards: highRisk, overdueCapas: overdueCapas, seriousIncidents30d: seriousIncidents30d),
        kpi: kpi,
        incidentTrend: trend,
        deptRanking: DashboardScope.showsDeptRanking(role) ? ranking.take(5).toList() : const [],
        generatedAt: now,
      );

      await _db.upsertCache(CachedRecordsCompanion(
        entityType: const Value(_cacheEntity), entityId: Value(userId),
        data: Value(jsonEncode(data.toJson())), syncStatus: const Value('synced'), updatedAt: Value(now),
      ),);
      return Ok(data);
    } catch (e, s) {
      _logger.warn('Dashboard: server unavailable, trying cache', e, s);
      final cached = (await _db.cachedByType(_cacheEntity)).where((c) => c.entityId == userId);
      if (cached.isNotEmpty) {
        try {
          return Ok(DashboardData.fromJson(jsonDecode(cached.first.data) as Map<String, dynamic>));
        } catch (_) {}
      }
      return const Err(NetworkFailure());
    }
  }
}
