// path: lib/features/capa/presentation/screens/capa_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/widgets/attachment_field.dart';
import 'package:ohs_shield_tracker/features/capa/domain/capa_workflow.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/widgets/capa_ui.dart';

class CapaDetailScreen extends ConsumerWidget {
  const CapaDetailScreen({required this.capaId, super.key});
  final String capaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(capaDetailProvider(capaId));
    return Scaffold(
      appBar: AppBar(title: const Text('Corrective action')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (capa) => _Body(capa: capa),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.capa});
  final CorrectiveAction capa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(capaControllerProvider).isLoading;
    final to = CapaWorkflow.next(capa.status);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text(capa.description, style: Theme.of(context).textTheme.titleLarge)),
        PriorityPill(priority: capa.priority),
      ],),
      const SizedBox(height: 4),
      Text('${capaSourceLabel(capa.source)} · ${capa.status.label}', style: Theme.of(context).textTheme.labelSmall),
      if (_sourceRoute() != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.push(_sourceRoute()!),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text('Open ${_sourceNoun()}'),
          ),
        ),
      if (capa.isOverdue)
        const Padding(padding: EdgeInsets.only(top: 4), child: Text('Overdue', style: TextStyle(color: AppColors.criticalRed, fontWeight: FontWeight.w700))),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(capa.hasOwner ? 'Owner assigned' : 'Unassigned'),
        trailing: TextButton(onPressed: busy ? null : () => _assignOwner(context, ref), child: const Text('Assign')),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(capa.dueDate == null ? 'No due date' : 'Due ${DateFormat.yMMMd().format(capa.dueDate!)}'),
        trailing: TextButton(onPressed: busy ? null : () => _setDueDate(context, ref), child: const Text('Set')),
      ),
      const SizedBox(height: 16),
      Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      AttachmentField(ownerType: AttachmentOwnerType.correctiveAction, ownerId: capa.id, title: ''),
      const SizedBox(height: 16),
      if (to != null)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: busy ? null : () => _advance(context, ref, to),
            child: Text(CapaWorkflow.advanceLabel(capa.status) ?? 'Advance'),
          ),
        ),
      if (to == CapaStatus.closed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Verify & close requires Safety Officer+ and verification evidence.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
        ),
    ],);
  }

  /// Route to the CAPA's originating record, or null when it can't be opened
  /// (e.g. an inspection-item source, which has no standalone detail page).
  String? _sourceRoute() {
    if (capa.hazardId != null) return Routes.hazardDetail(capa.hazardId!);
    if (capa.incidentId != null) return Routes.incidentDetail(capa.incidentId!);
    if (capa.investigationId != null) return Routes.investigationDetail(capa.investigationId!);
    return null;
  }

  String _sourceNoun() => switch (capa.source) {
        CapaSource.hazard => 'hazard',
        CapaSource.incident => 'incident',
        CapaSource.investigation => 'investigation',
        _ => 'source',
      };

  Future<void> _assignOwner(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(companyUsersProvider.future);
    if (!context.mounted) return;
    final chosen = await showDialog<String?>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Assign owner'), children: [
        for (final u in users) SimpleDialogOption(onPressed: () => Navigator.pop(c, u.id), child: Text(u.name)),
      ],),
    );
    if (chosen == null) return;
    final ok = await ref.read(capaControllerProvider.notifier).patch(capa, {'owner_id': chosen});
    if (context.mounted) _snack(context, ref, ok, 'Owner assigned');
  }

  Future<void> _setDueDate(BuildContext context, WidgetRef ref) async {
    final d = await showDatePicker(context: context, initialDate: capa.dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (d == null) return;
    final ok = await ref.read(capaControllerProvider.notifier).patch(capa, {'due_date': d.toIso8601String().substring(0, 10)});
    if (context.mounted) _snack(context, ref, ok, 'Due date set');
  }

  Future<void> _advance(BuildContext context, WidgetRef ref, CapaStatus to) async {
    final ok = await ref.read(capaControllerProvider.notifier).advance(capa, to);
    if (context.mounted) _snack(context, ref, ok, to.label);
  }

  void _snack(BuildContext context, WidgetRef ref, bool ok, String success) {
    final f = ref.read(capaControllerProvider).error;
    final msg = ok ? success : (f is Failure ? f.message : 'Action failed');
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
  }
}
