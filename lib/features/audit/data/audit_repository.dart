// path: lib/features/audit/data/audit_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/audit/data/audit_log_dto.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_filter.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_log_entry.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// READ-ONLY access to `audit_logs`. Exposes only SELECT — no insert/update/
/// delete method exists (RLS also blocks mutation; Prompt 2B). Visible to
/// Safety Officer/Manager/Administrator (RLS `audit_select` rank ≥3).
final class AuditRepository extends BaseRepository {
  AuditRepository(this._client, LoggerService logger) : super(logger);
  final SupabaseClient _client;

  Future<Result<List<AuditLogEntry>>> list(AuditFilter filter) => run(() async {
        var q = _client.from('audit_logs').select();
        if (filter.actorId != null) q = q.eq('actor_id', filter.actorId!);
        if (filter.entityType != null) q = q.eq('entity_type', filter.entityType!);
        if (filter.action != null && filter.action!.trim().isNotEmpty) {
          q = q.ilike('action', '%${filter.action!.trim()}%');
        }
        if (filter.from != null) q = q.gte('created_at', filter.from!.toIso8601String());
        if (filter.to != null) q = q.lte('created_at', filter.to!.toIso8601String());
        final rows = await q.order('created_at', ascending: false).limit(200);
        return [for (final r in rows) AuditLogDto.fromJson(r).toEntity()];
      }, context: 'listAudit',);

  Future<Result<AuditLogEntry>> get(String id) => run(() async {
        final row = await _client.from('audit_logs').select().eq('id', id).single();
        return AuditLogDto.fromJson(row).toEntity();
      }, context: 'getAudit',);
}
