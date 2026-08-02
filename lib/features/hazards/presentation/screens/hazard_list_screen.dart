// path: lib/features/hazards/presentation/screens/hazard_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/widgets/hazard_ui.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';
import 'package:ohs_shield_tracker/shared/widgets/sync_status_badge.dart';

class HazardListScreen extends ConsumerWidget {
  const HazardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazards = ref.watch(hazardListProvider);
    final filter = ref.watch(hazardFilterControllerProvider);
    final ctrl = ref.read(hazardFilterControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Hazards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.hazardNew),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Report'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search hazards', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (q) => ctrl.update(filter.copyWith(query: q)),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              ChoiceChip(label: const Text('All'), selected: filter.status == null && !filter.mineOnly,
                  onSelected: (_) => ctrl.update(filter.copyWith(clearStatus: true, mineOnly: false)),),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Mine'), selected: filter.mineOnly,
                  onSelected: (v) => ctrl.update(filter.copyWith(mineOnly: v)),),
              const SizedBox(width: 8),
              for (final s in HazardStatus.values) ...[
                ChoiceChip(label: Text(s.label), selected: filter.status == s,
                    onSelected: (_) => ctrl.update(filter.copyWith(status: s)),),
                const SizedBox(width: 8),
              ],
            ],),
          ),
          Expanded(
            child: hazards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load hazards: $e')),
              data: (list) => list.isEmpty
                  ? const _EmptyHazards()
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(hazardListProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _HazardRow(hazard: list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardRow extends ConsumerWidget {
  const _HazardRow({required this.hazard});
  final Hazard hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(recordSyncStatusProvider((type: SyncEntity.hazard, id: hazard.id))).valueOrNull;
    return Card(
      child: ListTile(
        onTap: () => context.push(Routes.hazardDetail(hazard.id)),
        leading: DuotoneIconBadge(icon: hazardCategoryIcon(hazard.category), color: hazardRiskColor(hazard.riskLevel)),
        title: Text(hazard.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${hazard.category.label} · ${hazard.status.label}',
            style: Theme.of(context).textTheme.labelSmall,),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (syncStatus != null && syncStatus != SyncStatus.synced)
            Padding(padding: const EdgeInsets.only(right: 6), child: SyncBadge(status: syncStatus)),
          HazardStatusPill(status: hazard.status, risk: hazard.riskLevel),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],),
      ),
    );
  }
}

class _EmptyHazards extends StatelessWidget {
  const _EmptyHazards();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_outlined, size: 48, color: AppColors.primaryGreen),
            const SizedBox(height: 12),
            Text('No open hazards on this site — nice work.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),),
          ],),
        ),
      );
}
