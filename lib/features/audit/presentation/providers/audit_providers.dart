// path: lib/features/audit/presentation/providers/audit_providers.dart
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/audit/data/audit_repository.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_filter.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_log_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'audit_providers.g.dart';

@riverpod
AuditRepository auditRepository(AuditRepositoryRef ref) =>
    AuditRepository(ref.watch(supabaseClientProvider), ref.watch(loggerProvider));

@riverpod
class AuditFilterController extends _$AuditFilterController {
  @override
  AuditFilter build() => const AuditFilter();
  void update(AuditFilter f) => state = f;
  void clear() => state = const AuditFilter();
}

@riverpod
Future<List<AuditLogEntry>> auditList(AuditListRef ref) async {
  final filter = ref.watch(auditFilterControllerProvider);
  final res = await ref.watch(auditRepositoryProvider).list(filter);
  return res.when(ok: (l) => l, err: (f) => throw f);
}

@riverpod
Future<AuditLogEntry> auditDetail(AuditDetailRef ref, String id) async {
  final res = await ref.watch(auditRepositoryProvider).get(id);
  return res.when(ok: (e) => e, err: (f) => throw f);
}
