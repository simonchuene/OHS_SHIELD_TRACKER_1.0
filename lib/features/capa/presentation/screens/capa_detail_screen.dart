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
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/widgets/capa_ui.dart';
import 'package:ohs_shield_tracker/shared/widgets/rank_gated_action.dart';
import 'package:ohs_shield_tracker/shared/widgets/skeleton.dart';
import 'package:ohs_shield_tracker/shared/widgets/select_one_dialog.dart';
import 'package:ohs_shield_tracker/shared/widgets/status_stepper.dart';
import 'package:ohs_shield_tracker/core/utils/user_lookup.dart';

class CapaDetailScreen extends ConsumerWidget {
  const CapaDetailScreen({required this.capaId, super.key});
  final String capaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(capaDetailProvider(capaId));
    return Scaffold(
      appBar: AppBar(title: const Text('Corrective action')),
      body: async.when(
        loading: () => const SkeletonDetail(),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        // Pull-to-refresh, as the hazard detail already has. A CAPA opened from
        // a notification can be read before the assigning device's outbox has
        // synced, and a FutureProvider will not re-fetch on its own — leaving a
        // stale record with no way to reload short of leaving the screen.
        data: (capa) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(capaDetailProvider(capaId)),
          child: _Body(capa: capa),
        ),
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
        // Show who holds it, not just that someone does. Falls back to a neutral
        // label while the company roster loads, or if the owner is outside this
        // user's RLS-visible scope so their name cannot be resolved.
        title: Text(_ownerLabel(ref)),
        trailing: TextButton(onPressed: busy ? null : () => _assignOwner(context, ref), child: const Text('Assign')),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(capa.dueDate == null ? 'No due date' : 'Due ${DateFormat.yMMMd().format(capa.dueDate!)}'),
        trailing: TextButton(onPressed: busy ? null : () => _setDueDate(context, ref), child: const Text('Set')),
      ),
      if ((capa.completionNotes ?? '').trim().isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Work completed', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(capa.completionNotes!.trim(), style: Theme.of(context).textTheme.bodyMedium),
      ],
      const SizedBox(height: 16),
      Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      AttachmentField(ownerType: AttachmentOwnerType.correctiveAction, ownerId: capa.id, title: ''),
      const SizedBox(height: 16),
      if (to != null) ...[
        Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StatusStepper(
          labels: [for (final s in CapaStatus.values) s.label],
          currentIndex: CapaStatus.values.indexOf(capa.status),
        ),
        const SizedBox(height: 12),
        // State the CAPA's current position and where the button moves it. The
        // button names the *next* action, so on its own it reads as the state:
        // tapping "Start work" and immediately seeing "Submit for verification"
        // looks like a step was skipped rather than completed. Mirrors the
        // hazard screen, which already shows a "Next step" line.
        Row(children: [
          Text('Status: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText)),
          Text(capa.status.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],),
        Text('Next: ${to.label}', style: Theme.of(context).textTheme.bodyMedium),
        if (to == CapaStatus.closed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Verify & close requires Safety Officer+ and verification evidence.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
          ),
        const SizedBox(height: 12),
        RankGatedAction(
          minRank: CapaWorkflow.minRankFor(to),
          // A CAPA's owner may start work without Supervisor rank (Ledger §10,
          // RLS migration 0016). Null elsewhere, so the rank check applies.
          permitted: _ownerMayAct(ref, capa, to) ? true : null,
          onPressed: busy ? null : () => _advance(context, ref, to),
          child: Text(CapaWorkflow.advanceLabel(capa.status) ?? 'Advance'),
        ),
      ],
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

  /// `Assigned: <name>` when the owner resolves, otherwise a neutral label. The
  /// CAPA row carries only `owner_id`, so the name comes from the company roster
  /// the assign picker already loads.
  String _ownerLabel(WidgetRef ref) {
    if (!capa.hasOwner) return 'Unassigned';
    final name = nameForUser(ref.watch(companyUsersProvider).valueOrNull, capa.ownerId);
    return name == null ? 'Assigned' : 'Assigned: $name';
  }

  Future<void> _assignOwner(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(companyUsersProvider.future);
    if (!context.mounted) return;
    final chosen = await showSelectOneDialog<String>(
      context: context,
      title: 'Assign owner',
      confirmLabel: 'Assign',
      // Pre-select the current owner so reopening the picker shows who holds it,
      // and confirming without changing anything is a no-op rather than a
      // surprise reassignment.
      initialValue: capa.ownerId,
      options: [for (final u in users) (value: u.id, label: u.name)],
      emptyMessage: 'No users available to assign.',
    );
    if (chosen == null || chosen == capa.ownerId) return;
    final changes = <String, dynamic>{'owner_id': chosen};
    // Giving a Created CAPA an owner *is* the Assign step, so move the status
    // too — `create` already does this (`status: ownerId != null ? assigned :
    // created`), but this path only ever wrote owner_id. The record stayed in
    // Created, so the owner opened it to a greyed-out "Assign" button (that step
    // needs Supervisor rank) and could never reach "Start work".
    if (capa.status == CapaStatus.created) {
      changes['status'] = CapaStatus.assigned.dbValue;
    }
    final ok = await ref.read(capaControllerProvider.notifier).patch(capa, changes);
    if (context.mounted) _snack(context, ref, ok, 'Owner assigned');
  }

  Future<void> _setDueDate(BuildContext context, WidgetRef ref) async {
    final d = await showDatePicker(context: context, initialDate: capa.dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (d == null) return;
    final ok = await ref.read(capaControllerProvider.notifier).patch(capa, {'due_date': d.toIso8601String().substring(0, 10)});
    if (context.mounted) _snack(context, ref, ok, 'Due date set');
  }

  /// The assigned owner may run their own CAPA through the doing phase without
  /// a rank: Assigned -> In Progress (Ledger §10, RLS 0016) and In Progress ->
  /// Verification (§17, RLS 0018 — "I have finished, please check"). Closing
  /// still requires Safety Officer+, so an owner can never verify or close
  /// their own work.
  bool _ownerMayAct(WidgetRef ref, CorrectiveAction capa, CapaStatus to) {
    if (to != CapaStatus.inProgress && to != CapaStatus.verification) return false;
    final userId = ref.watch(currentUserProvider).valueOrNull?.id;
    return userId != null && capa.ownerId == userId;
  }

  /// Prompt for the owner's account of the work when handing it back. Optional:
  /// an empty note still submits, because blocking the handover on a text field
  /// would push people to type "done" to get past it.
  Future<String?> _askCompletionNotes(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit for verification'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'What was done?',
            hintText: 'Describe the work completed (optional)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
  }

  Future<void> _advance(BuildContext context, WidgetRef ref, CapaStatus to) async {
    String? notes;
    if (to == CapaStatus.verification) {
      notes = await _askCompletionNotes(context);
      // Cancelled: abandon the transition entirely rather than submitting
      // silently. An empty string means "submit without notes" and proceeds.
      if (notes == null || !context.mounted) return;
    }
    final ok = await ref.read(capaControllerProvider.notifier).advance(capa, to, completionNotes: notes);
    if (context.mounted) _snack(context, ref, ok, to.label);
  }

  void _snack(BuildContext context, WidgetRef ref, bool ok, String success) {
    final f = ref.read(capaControllerProvider).error;
    final msg = ok ? success : (f is Failure ? f.message : 'Action failed');
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
  }
}
