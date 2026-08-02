// path: lib/features/capa/presentation/screens/capa_board_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/widgets/capa_ui.dart';

/// Actions tab — CAPA board with Kanban / List toggle.
class CapaBoardScreen extends ConsumerStatefulWidget {
  const CapaBoardScreen({super.key});
  @override
  ConsumerState<CapaBoardScreen> createState() => _CapaBoardScreenState();
}

class _CapaBoardScreenState extends ConsumerState<CapaBoardScreen> {
  bool _kanban = true;

  @override
  Widget build(BuildContext context) {
    final capas = ref.watch(capaListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actions'),
        actions: [
          IconButton(
            tooltip: _kanban ? 'List view' : 'Kanban view',
            icon: Icon(_kanban ? Icons.view_list_rounded : Icons.view_kanban_rounded),
            onPressed: () => setState(() => _kanban = !_kanban),
          ),
        ],
      ),
      body: capas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load actions: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Nothing to action right now.')))
            : (_kanban ? _Kanban(list: list) : _List(list: list)),
      ),
    );
  }
}

class _Kanban extends StatelessWidget {
  const _Kanban({required this.list});
  final List<CorrectiveAction> list;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final status in CapaStatus.values)
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('${status.label} · ${list.where((c) => c.status == status).length}',
                    style: Theme.of(context).textTheme.titleLarge,),
              ),
              for (final c in list.where((c) => c.status == status)) _CapaCard(capa: c),
            ],),
          ),
      ],),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.list});
  final List<CorrectiveAction> list;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final c in list) _CapaCard(capa: c)],
      );
}

class _CapaCard extends StatelessWidget {
  const _CapaCard({required this.capa});
  final CorrectiveAction capa;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push('${Routes.capa}/${capa.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(capa.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Row(children: [
              PriorityPill(priority: capa.priority),
              const Spacer(),
              if (capa.dueDate != null)
                Text(DateFormat.MMMd().format(capa.dueDate!),
                    style: TextStyle(fontSize: 11, color: capa.isOverdue ? AppColors.criticalRed : AppColors.secondaryText, fontWeight: capa.isOverdue ? FontWeight.w700 : FontWeight.w400),),
            ],),
            if (capa.isOverdue)
              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Overdue', style: TextStyle(fontSize: 11, color: AppColors.criticalRed, fontWeight: FontWeight.w700))),
          ],),
        ),
      ),
    );
  }
}
