// path: lib/features/investigations/presentation/screens/investigation_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/providers/investigation_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';

class InvestigationListScreen extends ConsumerWidget {
  const InvestigationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investigations = ref.watch(investigationsAllProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Investigations')),
      body: investigations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No investigations yet.\nStart one from a hazard or incident.', textAlign: TextAlign.center)))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(investigationsAllProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final inv = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('${Routes.investigations}/${inv.id}'),
                        leading: DuotoneIconBadge(icon: Icons.search_rounded, color: AppColors.infoBlue),
                        title: Text('${inv.originatesFromIncident ? 'Incident' : 'Hazard'} investigation'),
                        subtitle: Text('${inv.method?.label ?? 'No method'} · ${inv.status.label}', style: Theme.of(context).textTheme.labelSmall),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
