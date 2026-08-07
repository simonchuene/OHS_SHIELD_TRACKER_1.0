// path: lib/features/dashboard/data/priority_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/priority_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cacheEntity = 'priorities';

/// The Today's Priorities list plus whether it came from the offline snapshot.
class PrioritySnapshot {
  const PrioritySnapshot({required this.items, required this.generatedAt, this.fromCache = false});
  final List<PriorityItem> items;
  final DateTime generatedAt;
  final bool fromCache;
}

/// Builds the ranked priorities list from RLS-scoped queries and caches the
/// *computed* result as a snapshot (same approach as [DashboardRepository]).
///
/// Deliberately a whole-list snapshot rather than a merge of the per-entity
/// caches: only hazards cache on read, so merging would silently drop CAPAs and
/// incidents and produce a worklist that looks authoritative but is incomplete —
/// worse than showing a clearly-labelled saved copy.
class PriorityRepository {
  PriorityRepository(this._client, this._db, this._logger);
  final SupabaseClient _client;
  final AppDatabase _db;
  final LoggerService _logger;

  static const _limit = 5;

  Future<PrioritySnapshot> load(String userId) async {
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        _client.from('hazards').select('id,title,status,risk_level,location_text,updated_at').neq('status', 'closed'),
        _client.from('corrective_actions').select('id,description,status,priority,due_date,updated_at').neq('status', 'closed'),
        _client.from('incidents').select('id,description,incident_type,severity,status,location_text,updated_at').neq('status', 'closed'),
      ]).timeout(const Duration(seconds: 8));

      final items = <PriorityItem>[
        for (final h in results[0]) PriorityItem.fromHazard(h),
        for (final c in results[1]) PriorityItem.fromCapa(c),
        for (final i in results[2]) PriorityItem.fromIncident(i),
      ]..sort(PriorityItem.compare);

      final top = items.take(_limit).toList();
      await _cache(userId, top, now);
      return PrioritySnapshot(items: top, generatedAt: now);
    } catch (e, s) {
      _logger.warn('Priorities: server unavailable, trying snapshot', e, s);
      final cached = await _readCache(userId);
      if (cached != null) return cached;
      rethrow; // no snapshot yet — let the UI surface a real error
    }
  }

  Future<void> _cache(String userId, List<PriorityItem> items, DateTime at) async {
    try {
      await _db.upsertCache(CachedRecordsCompanion(
        entityType: const Value(_cacheEntity),
        entityId: Value(userId),
        data: Value(jsonEncode({
          'generatedAt': at.toIso8601String(),
          'items': [for (final i in items) i.toJson()],
        }),),
        syncStatus: const Value('synced'),
        updatedAt: Value(at),
      ),);
    } catch (e, s) {
      _logger.warn('Priorities: snapshot write failed', e, s); // best-effort
    }
  }

  Future<PrioritySnapshot?> _readCache(String userId) async {
    try {
      final rows = (await _db.cachedByType(_cacheEntity)).where((r) => r.entityId == userId);
      if (rows.isEmpty) return null;
      final json = jsonDecode(rows.first.data) as Map<String, dynamic>;
      return PrioritySnapshot(
        items: [
          for (final i in (json['items'] as List? ?? []))
            PriorityItem.fromJson(Map<String, dynamic>.from(i as Map)),
        ],
        generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? rows.first.updatedAt,
        fromCache: true,
      );
    } catch (e, s) {
      _logger.warn('Priorities: snapshot unreadable', e, s);
      return null;
    }
  }
}
