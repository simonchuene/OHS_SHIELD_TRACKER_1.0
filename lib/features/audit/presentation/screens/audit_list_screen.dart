// path: lib/features/audit/presentation/screens/audit_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/utils/date_time_x.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_filter.dart';
import 'package:ohs_shield_tracker/features/audit/presentation/providers/audit_providers.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart' show companyUsersProvider;

/// Audit Log Viewer — read-only, filterable/searchable. No mutation controls.
class AuditListScreen extends ConsumerWidget {
  const AuditListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditListProvider);
    final filter = ref.watch(auditFilterControllerProvider);
    final ctrl = ref.read(auditFilterControllerProvider.notifier);
    final users = ref.watch(companyUsersProvider).valueOrNull ?? [];
    final userName = {for (final u in users) u.id: u.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [IconButton(icon: const Icon(Icons.filter_alt_off_outlined), tooltip: 'Clear filters', onPressed: ctrl.clear)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search action (e.g. capa.closed)', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (q) => ctrl.update(filter.copyWith(action: q)),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            ChoiceChip(label: const Text('All entities'), selected: filter.entityType == null, onSelected: (_) => ctrl.update(filter.copyWith(clearEntity: true))),
            const SizedBox(width: 8),
            for (final t in AuditFilter.entityTypes) ...[
              ChoiceChip(label: Text(t), selected: filter.entityType == t, onSelected: (_) => ctrl.update(filter.copyWith(entityType: t))),
              const SizedBox(width: 8),
            ],
          ],),
        ),
        Expanded(
          child: logs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load audit log: $e')),
            data: (list) => list.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No audit entries match your filters.')))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(auditListProvider),
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = list[i];
                        return ListTile(
                          title: Text(e.action, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${e.entityType} · ${e.actorId != null ? (userName[e.actorId] ?? 'User') : 'System'} · ${DateFormat.yMMMd().add_jm().format(e.createdAt.local)}',
                              style: Theme.of(context).textTheme.labelSmall,),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                          onTap: () => context.push('/audit/${e.id}'),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],),
    );
  }
}
