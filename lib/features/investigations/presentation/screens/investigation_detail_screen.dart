// path: lib/features/investigations/presentation/screens/investigation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/widgets/attachment_field.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/investigation_workflow.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/providers/investigation_providers.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/widgets/fishbone_editor.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/widgets/five_whys_editor.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/widgets/investigation_timeline.dart';
import 'package:ohs_shield_tracker/shared/widgets/rank_gated_action.dart';
import 'package:ohs_shield_tracker/shared/widgets/status_stepper.dart';
import 'package:ohs_shield_tracker/core/utils/user_lookup.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';

class InvestigationDetailScreen extends ConsumerWidget {
  const InvestigationDetailScreen({required this.investigationId, super.key});
  final String investigationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(investigationDetailProvider(investigationId));
    return Scaffold(
      appBar: AppBar(title: const Text('Investigation')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load investigation: $e')),
        data: (inv) => _Editor(key: ValueKey(inv.id + inv.version.toString()), investigation: inv),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.investigation, super.key});
  final Investigation investigation;
  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final TextEditingController _immediate;
  late final TextEditingController _contributing;
  late final TextEditingController _rootCause;
  late final TextEditingController _recommendations;
  InvestigationMethod? _method;
  late InvestigationAnalysis _analysis;

  Investigation get inv => widget.investigation;

  @override
  void initState() {
    super.initState();
    _immediate = TextEditingController(text: inv.immediateCause);
    _contributing = TextEditingController(text: inv.contributingFactors);
    _rootCause = TextEditingController(text: inv.rootCause);
    _recommendations = TextEditingController(text: inv.recommendations);
    _method = inv.method;
    _analysis = inv.analysis;
  }

  @override
  void dispose() {
    _immediate.dispose();
    _contributing.dispose();
    _rootCause.dispose();
    _recommendations.dispose();
    super.dispose();
  }

  Map<String, dynamic> _changes() => {
        'method': _method?.dbValue,
        'immediate_cause': _immediate.text.trim(),
        'contributing_factors': _contributing.text.trim(),
        'root_cause': _rootCause.text.trim(),
        'recommendations': _recommendations.text.trim(),
        'analysis': _analysis.toJson(),
      };

  Future<void> _save() async {
    final ok = await ref.read(investigationControllerProvider.notifier).saveDetails(inv, _changes());
    if (mounted) _snack(ok ? 'Saved' : _err());
  }

  Future<void> _advance() async {
    final to = InvestigationWorkflow.next(inv.status);
    if (to == null) return;
    // Save current edits first so completion guards see the latest root cause/recs.
    await ref.read(investigationControllerProvider.notifier).saveDetails(inv, _changes());
    final refreshed = inv.copyWith(
      rootCause: _rootCause.text.trim(),
      recommendations: _recommendations.text.trim(),
    );
    final ok = await ref.read(investigationControllerProvider.notifier).advance(refreshed, to);
    if (mounted) _snack(ok ? to.label : _err());
  }

  Future<void> _generateCapa() async {
    final descC = TextEditingController();
    var priority = 'medium';
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Corrective action'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description *')),
          DropdownButtonFormField<String>(
            initialValue: priority,
            items: const [
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'low', child: Text('Low')),
            ],
            onChanged: (v) => priority = v ?? 'medium',
            decoration: const InputDecoration(labelText: 'Priority'),
          ),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, descC.text.trim().isNotEmpty), child: const Text('Create')),
        ],
      ),
    );
    if (go != true) return;
    final ok = await ref.read(investigationControllerProvider.notifier).generateCapa(inv, descC.text.trim(), priority);
    if (mounted) _snack(ok ? 'CAPA created' : _err());
  }

  String _err() {
    final f = ref.read(investigationControllerProvider).error;
    return f is Failure ? f.message : 'Action failed';
  }

  void _snack(String m) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

  /// `Assigned: <name>` for the investigator. Falls back to a bare "Assigned"
  /// when the roster has not loaded or the user is outside RLS-visible scope —
  /// `investigator_id` is non-null, so there is always someone assigned.
  String _assigneeLabel(WidgetRef ref) {
    final name = nameForUser(ref.watch(companyUsersProvider).valueOrNull, inv.investigatorId);
    return name == null ? 'Assigned' : 'Assigned: $name';
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(investigationControllerProvider).isLoading;
    // Conduct Investigation = Supervisor+ (RBAC matrix). Folded into canEdit so
    // the analysis fields are read-only for lower ranks too, not just the
    // buttons — otherwise a user can type freely and only be refused on save.
    final mayAct = hasMinRank(ref, InvestigationWorkflow.minRank());
    final canEdit = !inv.isCompleted && mayAct;
    final to = InvestigationWorkflow.next(inv.status);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Origin: ${inv.originatesFromIncident ? 'Incident' : 'Hazard'}', style: Theme.of(context).textTheme.bodyMedium)),
        Chip(label: Text(inv.status.label)),
      ],),
      // `investigator_id` is this record's assignee, so it takes the same
      // "Assigned: <name>" wording as a CAPA's owner.
      Text(
        _assigneeLabel(ref),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<InvestigationMethod>(
        initialValue: _method,
        decoration: const InputDecoration(labelText: 'Method'),
        items: [for (final m in InvestigationMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
        onChanged: canEdit ? (v) => setState(() => _method = v) : null,
      ),
      const SizedBox(height: 12),
      if (_method == InvestigationMethod.fishbone)
        FishboneEditor(value: _analysis.fishbone, onChanged: (m) => _analysis = _analysis.copyWith(fishbone: m))
      else
        FiveWhysEditor(value: _analysis.fiveWhys, onChanged: (w) => _analysis = _analysis.copyWith(fiveWhys: w)),
      const SizedBox(height: 12),
      TextField(controller: _immediate, enabled: canEdit, decoration: const InputDecoration(labelText: 'Immediate cause')),
      const SizedBox(height: 12),
      TextField(controller: _contributing, enabled: canEdit, maxLines: 2, decoration: const InputDecoration(labelText: 'Contributing factors')),
      const SizedBox(height: 12),
      TextField(controller: _rootCause, enabled: canEdit, maxLines: 2, decoration: const InputDecoration(labelText: 'Root cause *', helperText: 'Required to complete')),
      const SizedBox(height: 12),
      TextField(controller: _recommendations, enabled: canEdit, maxLines: 3, decoration: const InputDecoration(labelText: 'Recommendations *', helperText: 'Required to complete')),
      const SizedBox(height: 16),
      if (canEdit)
        OutlinedButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save_outlined, size: 18), label: const Text('Save details')),
      const SizedBox(height: 16),
      Text('Evidence', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      AttachmentField(ownerType: AttachmentOwnerType.investigation, ownerId: inv.id, title: ''),
      const SizedBox(height: 16),
      Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      InvestigationTimeline(investigation: inv),
      const SizedBox(height: 8),
      // Conduct Investigation and Create/Assign CAPA are both Supervisor+ in the
      // RBAC matrix. These sit in a Wrap rather than being full-width, so they
      // use `hasMinRank` directly with a shared denial note beneath.
      Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      StatusStepper(
        labels: [for (final s in InvestigationStatus.values) s.label],
        currentIndex: InvestigationStatus.values.indexOf(inv.status),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text('Status: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText)),
        Text(inv.status.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],),
      if (to != null) Text('Next: ${to.label}', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (to != null)
          ElevatedButton(
            onPressed: (busy || !mayAct) ? null : _advance,
            child: Text(InvestigationWorkflow.advanceLabel(inv.status) ?? 'Advance'),
          ),
        OutlinedButton.icon(
          onPressed: (busy || !mayAct) ? null : _generateCapa,
          icon: const Icon(Icons.add_task_rounded, size: 18),
          label: const Text('Add CAPA'),
        ),
      ],),
      if (!mayAct) const RoleDeniedNote(),
      if (to == InvestigationStatus.completed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Completing requires a root cause and recommendations.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
        ),
    ],);
  }
}
