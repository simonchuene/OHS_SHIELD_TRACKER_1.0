// path: lib/features/reports/presentation/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/shared/widgets/nav_safe_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/reports/domain/report_models.dart';
import 'package:ohs_shield_tracker/features/reports/presentation/providers/report_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  ReportType _type = ReportType.hazardRegister;
  DateTime? _from;
  DateTime? _to;

  Future<void> _pickDate(bool isFrom) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  Future<void> _export(ReportFormat format) async {
    final path = await ref.read(reportControllerProvider.notifier).export(format);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(path == null ? 'Export failed' : 'Saved ${format.name.toUpperCase()} · $path')));
  }

  /// Exports (saving locally + recording history, exactly as Download does) and
  /// then opens the share sheet so the file can be emailed.
  Future<void> _email(ReportFormat format) async {
    final path = await ref.read(reportControllerProvider.notifier).emailReport(format);
    if (!mounted || path != null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not prepare the report to send')));
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(reportControllerProvider);
    final history = ref.watch(reportHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(padding: navSafeInsets(context), children: [
        DropdownButtonFormField<ReportType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Report'),
          items: [for (final t in ReportType.values) DropdownMenuItem(value: t, child: Text(t.title))],
          onChanged: (v) => setState(() => _type = v ?? ReportType.hazardRegister),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(_from == null ? 'From' : DateFormat.yMMMd().format(_from!)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(_to == null ? 'To' : DateFormat.yMMMd().format(_to!)))),
        ],),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => ref.read(reportControllerProvider.notifier).generate(_type, ReportFilters(from: _from, to: _to)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Generate'),
        ),
        const SizedBox(height: 16),
        result.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, _) => Text(e is Failure ? e.message : '$e', style: const TextStyle(color: AppColors.criticalRed)),
          data: (r) => r == null ? const SizedBox.shrink() : _Preview(result: r, onExport: _export, onEmail: _email),
        ),
        const SizedBox(height: 24),
        Text('Report history', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        history.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => items.isEmpty
              ? Text('No reports generated yet.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText))
              : Column(children: [
                  for (final h in items)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(h.format == ReportFormat.pdf ? Icons.picture_as_pdf_outlined : Icons.grid_on_outlined),
                      title: Text(h.title),
                      subtitle: Text('${h.format.name.toUpperCase()} · ${DateFormat.yMMMd().add_jm().format(h.generatedAt)}', style: Theme.of(context).textTheme.labelSmall),
                    ),
                ],),
        ),
      ],),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.result, required this.onExport, required this.onEmail});
  final ReportResult result;
  final void Function(ReportFormat) onExport;
  final void Function(ReportFormat) onEmail;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${result.title} · ${result.rowCount} row(s)', style: Theme.of(context).textTheme.titleLarge)),
      ],),
      const SizedBox(height: 8),
      // Download saves to the device; Email exports the same file and opens the
      // share sheet, so the local copy + history entry are kept either way.
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => onExport(ReportFormat.csv), icon: const Icon(Icons.grid_on_outlined, size: 18), label: const Text('Download CSV')),
        OutlinedButton.icon(onPressed: () => onExport(ReportFormat.pdf), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('Download PDF')),
        FilledButton.tonalIcon(onPressed: () => onEmail(ReportFormat.csv), icon: const Icon(Icons.mail_outline_rounded, size: 18), label: const Text('Email CSV')),
        FilledButton.tonalIcon(onPressed: () => onEmail(ReportFormat.pdf), icon: const Icon(Icons.mail_outline_rounded, size: 18), label: const Text('Email PDF')),
      ],),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [for (final c in result.columns) DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)))],
          rows: [
            for (final row in result.rows.take(50))
              DataRow(cells: [for (final cell in row) DataCell(Text(cell))]),
          ],
        ),
      ),
      if (result.rowCount > 50)
        Text('Showing first 50 of ${result.rowCount}. Export for the full set.', style: Theme.of(context).textTheme.labelSmall),
    ],);
  }
}
