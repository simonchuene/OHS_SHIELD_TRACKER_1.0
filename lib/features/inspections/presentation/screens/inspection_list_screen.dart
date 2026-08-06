// path: lib/features/inspections/presentation/screens/inspection_list_screen.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/shared/widgets/nav_safe_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/providers/inspection_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';

class InspectionListScreen extends ConsumerWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections = ref.watch(inspectionsListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inspections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('${Routes.inspections}/new'),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: inspections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load inspections: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No inspections yet.')))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(inspectionsListProvider),
                child: ListView.separated(
                  padding: navSafeInsets(context),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final insp = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push(Routes.inspectionRun(insp.id)),
                        leading: DuotoneIconBadge(icon: Icons.checklist_rounded, color: AppColors.primaryGreen),
                        title: Text(insp.type.label),
                        subtitle: Text(insp.status.label, style: Theme.of(context).textTheme.labelSmall),
                        trailing: insp.score != null
                            ? Text('${insp.score!.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]))
                            : const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
