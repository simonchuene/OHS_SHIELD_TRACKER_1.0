// path: lib/features/audit/presentation/screens/audit_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_log_entry.dart';
import 'package:ohs_shield_tracker/features/audit/presentation/providers/audit_providers.dart';

/// Read-only audit detail with a Before → After field diff.
class AuditDetailScreen extends ConsumerWidget {
  const AuditDetailScreen({required this.auditId, super.key});
  final String auditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditDetailProvider(auditId));
    return Scaffold(
      appBar: AppBar(title: const Text('Audit entry')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load entry: $e')),
        data: (e) {
          final diff = e.diff;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(e.action, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${e.entityType}${e.entityId != null ? ' · ${e.entityId}' : ''}', style: Theme.of(context).textTheme.labelSmall),
            Text(DateFormat.yMMMEd().add_jms().format(e.createdAt), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 16),
            Text('Changes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (diff.isEmpty)
              Text('No field-level changes recorded (e.g. a create or a status-only event).',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),)
            else
              for (final c in diff) _DiffRow(change: c),
          ],);
        },
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.change});
  final FieldChange change;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(change.field, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Side(label: 'Before', value: change.before, color: AppColors.criticalRed, muted: change.isAdded)),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.secondaryText),
            Expanded(child: _Side(label: 'After', value: change.after, color: AppColors.primaryGreen, muted: change.isRemoved)),
          ],),
        ],),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.value, required this.color, required this.muted});
  final String label;
  final String? value;
  final Color color;
  final bool muted;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          Text(value ?? '—', style: TextStyle(color: muted ? AppColors.secondaryText : AppColors.primaryText)),
        ],),
      );
}
