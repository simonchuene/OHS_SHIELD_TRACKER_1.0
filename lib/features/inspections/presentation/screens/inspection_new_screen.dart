// path: lib/features/inspections/presentation/screens/inspection_new_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/router/routes.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/presentation/providers/inspection_providers.dart';

class InspectionNewScreen extends ConsumerWidget {
  const InspectionNewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(inspectionControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('New inspection')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Choose a checklist', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final type in InspectionType.values)
              Card(
                child: ListTile(
                  title: Text(type.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final insp = await ref.read(inspectionControllerProvider.notifier).create(type);
                    if (!context.mounted) return;
                    if (insp != null) {
                      context.pushReplacement(Routes.inspectionRun(insp.id));
                    } else {
                      final f = ref.read(inspectionControllerProvider).error;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f is Failure ? f.message : 'Could not start inspection')));
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
