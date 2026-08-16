// path: lib/features/inspections/presentation/screens/inspection_run_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/widgets/attachment_field.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/inspection_scoring.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/providers/inspection_providers.dart';
import 'package:ohs_shield_tracker/shared/widgets/rank_gated_action.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/shared/widgets/status_stepper.dart';

/// Mobile inspection UX — run the checklist, mark each item, then submit (which
/// auto-creates a hazard + CAPA for every failed item).
class InspectionRunScreen extends ConsumerWidget {
  const InspectionRunScreen({required this.inspectionId, super.key});
  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inspectionDetailProvider(inspectionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (insp) => _Body(inspection: insp),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.inspection});
  final Inspection inspection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(inspectionControllerProvider).isLoading;
    final readOnly = inspection.isSubmitted;
    final allAnswered = InspectionScoring.allAnswered(inspection.items);

    return Column(children: [
      LinearProgressIndicator(
        value: inspection.items.isEmpty ? 0 : inspection.answeredCount / inspection.items.length,
        backgroundColor: const Color(0xFFE0E0E0),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Text('${inspection.type.label} · ${inspection.status.label}', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (inspection.score != null) Text('${inspection.score!.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],),
          const SizedBox(height: 8),
          StatusStepper(
            labels: [for (final s in InspectionStatus.values) s.label],
            currentIndex: InspectionStatus.values.indexOf(inspection.status),
          ),
          const SizedBox(height: 8),
          for (final item in inspection.items) _ItemRow(inspection: inspection, item: item, readOnly: readOnly),
          const SizedBox(height: 16),
          Text('Photos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          AttachmentField(ownerType: AttachmentOwnerType.inspection, ownerId: inspection.id, title: '', editable: !readOnly),
        ],),
      ),
      if (!readOnly)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Conduct Inspections = Supervisor+ (RBAC matrix). The inspection
            // domain carries no rank constant of its own, unlike the hazard /
            // incident / CAPA / investigation workflows.
            child: RankGatedAction(
              minRank: AppRole.supervisor.rank,
              onPressed: (busy || !allAnswered) ? null : () => _submit(context, ref),
              child: busy
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(allAnswered ? 'Submit inspection' : 'Answer all items to submit'),
            ),
          ),
        ),
    ],);
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(inspectionControllerProvider.notifier).submit(inspection);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submitted${inspection.failCount > 0 ? ' · ${inspection.failCount} hazard(s) + CAPA(s) created' : ''}'),),);
      context.pop();
    } else {
      final f = ref.read(inspectionControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Submit failed')));
    }
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.inspection, required this.item, required this.readOnly});
  final Inspection inspection;
  final InspectionItem item;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.position + 1}. ${item.prompt}', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Row(children: [
            for (final r in InspectionItemResult.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(r.label),
                  selected: item.result == r,
                  selectedColor: _color(r).withValues(alpha: 0.2),
                  onSelected: readOnly ? null : (_) => _set(context, ref, r),
                ),
              ),
          ],),
          if (item.isFail && !item.generated)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Creates a hazard + CAPA on submit', style: TextStyle(fontSize: 11, color: AppColors.criticalRed)),
            ),
          if (item.generated)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Hazard + CAPA created', style: TextStyle(fontSize: 11, color: AppColors.primaryGreen)),
            ),
        ],),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, InspectionItemResult r) async {
    String? notes;
    if (r == InspectionItemResult.fail) {
      final controller = TextEditingController();
      notes = await showDialog<String?>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Note (optional)'),
          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'What failed?')),
          actions: [FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('OK'))],
        ),
      );
    }
    await ref.read(inspectionControllerProvider.notifier).setItemResult(inspection, item.id, r, item.version, notes: notes);
  }

  Color _color(InspectionItemResult r) => switch (r) {
        InspectionItemResult.pass => AppColors.primaryGreen,
        InspectionItemResult.fail => AppColors.criticalRed,
        InspectionItemResult.na => AppColors.secondaryText,
      };
}
