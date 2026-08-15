// path: lib/features/incidents/presentation/screens/incident_list_screen.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/utils/date_time_x.dart';
import 'package:ohs_shield_tracker/shared/widgets/nav_safe_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/providers/incident_providers.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/widgets/incident_ui.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';
import 'package:ohs_shield_tracker/shared/widgets/sync_status_badge.dart';

class IncidentListScreen extends ConsumerWidget {
  const IncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentListProvider);
    final filter = ref.watch(incidentFilterControllerProvider);
    final ctrl = ref.read(incidentFilterControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Incidents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${Routes.incidents}/new'),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Report'),
      ),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            ChoiceChip(label: const Text('All'), selected: filter.severity == null,
                onSelected: (_) => ctrl.update(filter.copyWith(clearSeverity: true)),),
            const SizedBox(width: 8),
            for (final s in IncidentSeverity.values) ...[
              ChoiceChip(label: Text(s.label), selected: filter.severity == s,
                  onSelected: (_) => ctrl.update(filter.copyWith(severity: s)),),
              const SizedBox(width: 8),
            ],
          ],),
        ),
        Expanded(
          child: incidents.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load incidents: $e')),
            data: (list) => list.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No incidents reported. Keep it that way.', textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(incidentListProvider),
                    child: ListView.separated(
                      padding: navSafeInsets(context),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _IncidentRow(incident: list[i]),
                    ),
                  ),
          ),
        ),
      ],),
    );
  }
}

class _IncidentRow extends ConsumerWidget {
  const _IncidentRow({required this.incident});
  final Incident incident;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(recordSyncStatusProvider((type: 'incident', id: incident.id))).valueOrNull;
    return Card(
      child: ListTile(
        onTap: () => context.push('${Routes.incidents}/${incident.id}'),
        leading: DuotoneIconBadge(icon: incidentTypeIcon(incident.type), color: incidentSeverityColor(incident.severity)),
        title: Text(incident.type.label),
        subtitle: Text('${DateFormat.yMMMd().add_jm().format(incident.occurredAt.local)} · ${incident.status.label}',
            style: Theme.of(context).textTheme.labelSmall,),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (sync != null && sync != SyncStatus.synced)
            Padding(padding: const EdgeInsets.only(right: 6), child: SyncBadge(status: sync)),
          SeverityPill(severity: incident.severity),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],),
      ),
    );
  }
}
