// path: lib/features/incidents/presentation/screens/incident_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/utils/date_time_x.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/widgets/attachment_field.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/incident_workflow.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/providers/incident_providers.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/widgets/incident_ui.dart';
import 'package:ohs_shield_tracker/shared/widgets/rank_gated_action.dart';
import 'package:ohs_shield_tracker/shared/widgets/select_one_dialog.dart';
import 'package:ohs_shield_tracker/shared/widgets/status_stepper.dart';
import 'package:ohs_shield_tracker/core/utils/user_lookup.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({required this.incidentId, super.key});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(incidentDetailProvider(incidentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Incident')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load incident: $e')),
        data: (i) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(incidentDetailProvider(incidentId)),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Text(i.type.label, style: Theme.of(context).textTheme.headlineMedium)),
              SeverityPill(severity: i.severity),
            ],),
            const SizedBox(height: 8),
            _kv('Occurred', DateFormat.yMMMd().add_jm().format(i.occurredAt.local)),
            _kv('Status', i.status.label),
            // Deliberately "Reported by", not "Assigned": incidents have no
            // assignee column. `reporter_id` is who raised it, and labelling
            // that as an assignment would imply an ownership the record does
            // not carry. Work on an incident is tracked through its linked
            // investigation and CAPAs, which do have owners.
            _kv('Reported by', _reporterName(ref, i) ?? '—'),
            if (i.description != null) _kv('Description', i.description!),
            if (i.locationText != null) _kv('Location', i.locationText!),
            if (i.isLinkedToHazard) _kv('Linked hazard', i.sourceHazardId!),
            if (i.witnesses.isNotEmpty) _kv('Witnesses', i.witnesses.map((w) => w.name).join(', ')),
            const SizedBox(height: 16),
            AttachmentField(ownerType: AttachmentOwnerType.incident, ownerId: i.id),
            const SizedBox(height: 16),
            _Workflow(incident: i),
            const SizedBox(height: 16),
            _Linkage(incident: i),
          ],),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.secondaryText))),
          Expanded(child: Text(v)),
        ],),
      );

  String? _reporterName(WidgetRef ref, Incident incident) =>
      nameForUser(ref.watch(companyUsersProvider).valueOrNull, incident.reporterId);
}

class _Workflow extends ConsumerWidget {
  const _Workflow({required this.incident});
  final Incident incident;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (incident.isClosed) {
      return Row(children: const [Icon(Icons.verified_rounded, color: AppColors.primaryGreen, size: 18), SizedBox(width: 8), Text('Incident closed')]);
    }
    final to = IncidentWorkflow.next(incident.status);
    if (to == null) return const SizedBox.shrink();
    final busy = ref.watch(incidentActionControllerProvider).isLoading;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      StatusStepper(
        labels: [for (final s in IncidentStatus.values) s.label],
        currentIndex: IncidentStatus.values.indexOf(incident.status),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text('Status: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText)),
        Text(incident.status.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],),
      Text('Next: ${to.label}'),
      if (to == IncidentStatus.closed)
        const Padding(padding: EdgeInsets.only(top: 4), child: Text('Closing needs verification evidence and all corrective actions closed.', style: TextStyle(fontSize: 11, color: AppColors.secondaryText))),
      const SizedBox(height: 12),
      RankGatedAction(
        minRank: IncidentWorkflow.minRankFor(to),
        onPressed: busy ? null : () async {
          final ok = await ref.read(incidentActionControllerProvider.notifier).advance(incident);
          if (context.mounted && !ok) {
            final f = ref.read(incidentActionControllerProvider).error;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Could not advance')));
          }
        },
        child: Text(IncidentWorkflow.advanceLabel(incident.status) ?? 'Advance'),
      ),
    ],);
  }
}

class _Linkage extends ConsumerWidget {
  const _Linkage({required this.incident});
  final Incident incident;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rank = ref.watch(authRoleRankProvider) ?? 0;
    if (rank < 2) return const SizedBox.shrink(); // Supervisor+ only
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Linkage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => _linkHazard(context, ref), icon: const Icon(Icons.link_rounded, size: 18), label: const Text('Link hazard')),
        OutlinedButton.icon(onPressed: () async {
          final ok = await ref.read(incidentActionControllerProvider.notifier).generateInvestigation(incident);
          if (context.mounted) _snack(context, ok ? null : ref.read(incidentActionControllerProvider).error, success: 'Investigation created');
        }, icon: const Icon(Icons.search_rounded, size: 18), label: const Text('Start investigation'),),
        OutlinedButton.icon(onPressed: () => _addCapa(context, ref), icon: const Icon(Icons.add_task_rounded, size: 18), label: const Text('Add CAPA')),
      ],),
    ],);
  }

  Future<void> _linkHazard(BuildContext context, WidgetRef ref) async {
    final hazards = await ref.read(hazardListProvider.future);
    if (!context.mounted) return;
    final chosen = await showSelectOneDialog<String>(
      context: context,
      title: 'Link to hazard',
      confirmLabel: 'Link',
      initialValue: incident.sourceHazardId,
      options: [for (final h in hazards.take(20)) (value: h.id, label: h.title)],
      emptyMessage: 'No hazards available.',
    );
    if (chosen == null || !context.mounted) return;
    final ok = await ref.read(incidentActionControllerProvider.notifier).linkToHazard(incident, chosen);
    if (context.mounted) _snack(context, ok ? null : ref.read(incidentActionControllerProvider).error, success: 'Linked to hazard');
  }

  Future<void> _addCapa(BuildContext context, WidgetRef ref) async {
    final descC = TextEditingController();
    var priority = 'medium';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add corrective action'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description *')),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'low', child: Text('Low')),
            ],
            onChanged: (v) => priority = v ?? 'medium',
          ),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, descC.text.trim().isNotEmpty), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final created = await ref.read(incidentActionControllerProvider.notifier).generateCapa(incident, descC.text.trim(), priority);
    if (context.mounted) _snack(context, created ? null : ref.read(incidentActionControllerProvider).error, success: 'CAPA created');
  }

  void _snack(BuildContext context, Object? failure, {String success = 'Done'}) {
    final msg = failure == null ? success : (failure is Failure ? failure.message : 'Action failed');
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));
  }
}
