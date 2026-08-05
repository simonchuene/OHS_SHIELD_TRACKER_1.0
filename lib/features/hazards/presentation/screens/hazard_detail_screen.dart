// path: lib/features/hazards/presentation/screens/hazard_detail_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/risk/presentation/providers/risk_providers.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/widgets/attachment_field.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/repositories/capa_repository.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/widgets/hazard_ui.dart';
import 'package:ohs_shield_tracker/features/investigations/presentation/providers/investigation_providers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/skeleton.dart';
import 'package:ohs_shield_tracker/shared/widgets/sync_status_badge.dart';

class HazardDetailScreen extends ConsumerWidget {
  const HazardDetailScreen({required this.hazardId, super.key});
  final String hazardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hazardDetailProvider(hazardId));
    return Scaffold(
      appBar: AppBar(title: const Text('Hazard')),
      body: async.when(
        loading: () => const SkeletonDetail(),
        error: (e, _) => Center(child: Text('Could not load hazard: $e')),
        data: (h) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(hazardDetailProvider(hazardId));
            ref.invalidate(capasForHazardProvider(hazardId));
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Text(h.title, style: Theme.of(context).textTheme.headlineMedium)),
              HazardStatusPill(status: h.status, risk: h.riskLevel),
            ],),
            const SizedBox(height: 4),
            Row(children: [
              Text(h.reference ?? 'Unreferenced', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              _SyncLine(hazardId: h.id),
            ],),
            const SizedBox(height: 16),
            _StatusStepper(status: h.status),
            const SizedBox(height: 16),
            _Section(title: 'Details', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv('Category', h.category.label),
              if (h.riskLevel != null) _kv('Risk level', h.riskLevel!.label),
              if (h.description != null) _kv('Description', h.description!),
              if (h.locationText != null) _kv('Location', h.locationText!),
              if (h.hasLocation) _kv('GPS', '${h.latitude!.toStringAsFixed(5)}, ${h.longitude!.toStringAsFixed(5)}'),
            ],),),
            const SizedBox(height: 16),
            _Section(
              title: '',
              child: AttachmentField(ownerType: AttachmentOwnerType.hazard, ownerId: h.id),
            ),
            const SizedBox(height: 16),
            _RiskSection(hazard: h),
            const SizedBox(height: 16),
            _WorkflowActions(hazard: h),
            const SizedBox(height: 16),
            _CorrectiveActions(hazard: h),
            const SizedBox(height: 16),
            _LinkagePlaceholder(hazard: h),
          ],),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(color: AppColors.secondaryText))),
          Expanded(child: Text(v)),
        ],),
      );
}

class _SyncLine extends ConsumerWidget {
  const _SyncLine({required this.hazardId});
  final String hazardId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(recordSyncStatusProvider((type: SyncEntity.hazard, id: hazardId))).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    return SyncBadge(status: s, compact: false);
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.status});
  final HazardStatus status;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final s in HazardStatus.values) ...[
          Icon(
            s.step <= status.step ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: s.step <= status.step ? AppColors.primaryGreen : AppColors.secondaryText,
          ),
          const SizedBox(width: 4),
          Text(s.label, style: TextStyle(fontSize: 11, color: s == status ? AppColors.primaryText : AppColors.secondaryText)),
          if (s != HazardStatus.closed) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('›', style: TextStyle(color: AppColors.secondaryText))),
        ],
      ],),
    );
  }
}

class _WorkflowActions extends ConsumerWidget {
  const _WorkflowActions({required this.hazard});
  final Hazard hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hazard.isClosed) {
      return _Section(
        title: 'Workflow',
        child: Row(children: const [
          Icon(Icons.verified_rounded, color: AppColors.primaryGreen, size: 18),
          SizedBox(width: 8),
          Text('Hazard closed'),
        ],),
      );
    }

    final to = HazardWorkflow.next(hazard.status);
    if (to == null) return const SizedBox.shrink();
    final rank = ref.watch(authRoleRankProvider) ?? 0;
    final permitted = rank >= HazardWorkflow.minRankFor(to);
    final busy = ref.watch(hazardWorkflowControllerProvider).isLoading;
    final label = HazardWorkflow.advanceLabel(hazard.status) ?? 'Advance';

    return _Section(
      title: 'Workflow',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Next step: ${to.label}', style: Theme.of(context).textTheme.bodyMedium),
        if (to == HazardStatus.closed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Closing requires verification evidence and all corrective actions closed.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!permitted || busy) ? null : () => _advance(context, ref),
            child: busy
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(label),
          ),
        ),
        if (!permitted)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Your role cannot perform this step.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),),
          ),
      ],),
    );
  }

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(hazardWorkflowControllerProvider.notifier).advance(hazard);
    if (!context.mounted) return;
    if (!ok) {
      final f = ref.read(hazardWorkflowControllerProvider).error;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Could not advance')));
    }
  }
}

class _RiskSection extends ConsumerWidget {
  const _RiskSection({required this.hazard});
  final Hazard hazard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestRiskProvider(hazard.id));
    final rank = ref.watch(authRoleRankProvider) ?? 0;
    return _Section(
      title: 'Risk assessment',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        latest.when(
          loading: () => const Text('…'),
          error: (_, __) => const Text('Could not load risk'),
          data: (a) => a == null
              ? Text('Not yet assessed', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText))
              : Row(children: [
                  HazardStatusPill(status: hazard.status, risk: a.band),
                  const SizedBox(width: 8),
                  Text('Score ${a.score} · ${a.band.label}${a.residualBand != null ? ' (residual ${a.residualBand!.label})' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,),
                ],),
        ),
        if (rank >= 2) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.hazardAssess(hazard.id)),
            icon: const Icon(Icons.assessment_outlined, size: 18),
            label: const Text('Assess risk'),
          ),
        ],
      ],),
    );
  }
}

class _CorrectiveActions extends ConsumerWidget {
  const _CorrectiveActions({required this.hazard});
  final Hazard hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capas = ref.watch(capasForHazardProvider(hazard.id));
    final rank = ref.watch(authRoleRankProvider) ?? 0;
    return _Section(
      title: 'Corrective actions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        capas.when(
          loading: () => const Text('…'),
          error: (_, __) => const Text('Could not load corrective actions'),
          data: (list) => list.isEmpty
              ? Text('None linked', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText))
              : Column(children: [
                  for (final c in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        c.isClosed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: c.isClosed ? AppColors.primaryGreen : AppColors.secondaryText,
                        size: 20,
                      ),
                      title: Text(c.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.status.label),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                      onTap: () => context.push(Routes.capaDetail(c.id)),
                    ),
                ],),
        ),
        if (rank >= 2) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _addCapa(context, ref),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('Add CAPA'),
          ),
        ],
      ],),
    );
  }

  Future<void> _addCapa(BuildContext context, WidgetRef ref) async {
    final descC = TextEditingController();
    var priority = CapaPriority.medium;
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Corrective action'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description *')),
          DropdownButtonFormField<CapaPriority>(
            initialValue: priority,
            items: [for (final p in CapaPriority.values) DropdownMenuItem(value: p, child: Text(p.label))],
            onChanged: (v) => priority = v ?? CapaPriority.medium,
            decoration: const InputDecoration(labelText: 'Priority'),
          ),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, descC.text.trim().isNotEmpty), child: const Text('Create')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final capa = await ref.read(capaControllerProvider.notifier).create(
          description: descC.text.trim(), priority: priority,
          source: CapaSourceRef(hazardId: hazard.id), siteId: hazard.siteId,
        );
    if (!context.mounted) return;
    if (capa != null) {
      // Refresh the linked list so the new action appears when we return.
      ref.invalidate(capasForHazardProvider(hazard.id));
      unawaited(context.push(Routes.capaDetail(capa.id)));
    } else {
      final f = ref.read(capaControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Could not create CAPA')));
    }
  }
}

class _LinkagePlaceholder extends ConsumerWidget {
  const _LinkagePlaceholder({required this.hazard});
  final Hazard hazard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investigations = ref.watch(investigationsForHazardProvider(hazard.id));
    final rank = ref.watch(authRoleRankProvider) ?? 0;
    return _Section(
      title: 'Investigations',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        investigations.when(
          loading: () => const Text('…'),
          error: (_, __) => const Text('Could not load investigations'),
          data: (list) => list.isEmpty
              ? Text('None yet', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText))
              : Column(children: [
                  for (final inv in list)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search_rounded),
                      title: Text(inv.method?.label ?? 'Investigation'),
                      subtitle: Text(inv.status.label),
                      onTap: () => context.push('${Routes.investigations}/${inv.id}'),
                    ),
                ],),
        ),
        if (rank >= 2) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _start(context, ref),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Start investigation'),
          ),
        ],
      ],),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final res = await ref.read(investigationUseCasesProvider).create(
          companyId: user.companyId, investigatorId: user.id, hazardId: hazard.id, siteId: hazard.siteId,
        );
    if (!context.mounted) return;
    res.when(
      ok: (inv) {
        ref.invalidate(investigationsForHazardProvider(hazard.id));
        context.push('${Routes.investigations}/${inv.id}');
      },
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title.isNotEmpty) ...[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
        ],
        child,
      ],);
}
