// path: lib/features/incidents/presentation/screens/incident_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/providers/attachment_providers.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_filter.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/witness.dart';
import 'package:ohs_shield_tracker/features/incidents/presentation/providers/incident_providers.dart';

class IncidentReportScreen extends ConsumerStatefulWidget {
  const IncidentReportScreen({super.key});
  @override
  ConsumerState<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends ConsumerState<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _location = TextEditingController();
  IncidentType _type = IncidentType.nearMiss;
  IncidentSeverity _severity = IncidentSeverity.minor;
  DateTime _occurredAt = DateTime.now();
  GpsLocation? _gps;
  final _witnesses = <Witness>[];
  final _media = <CapturedMedia>[];

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(context: context, initialDate: _occurredAt, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
    if (!mounted) return;
    setState(() => _occurredAt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
  }

  Future<void> _addWitness() async {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    final stmtC = TextEditingController();
    final w = await showDialog<Witness?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add witness'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name *')),
          TextField(controller: contactC, decoration: const InputDecoration(labelText: 'Contact (optional)')),
          TextField(controller: stmtC, decoration: const InputDecoration(labelText: 'Statement (optional)')),
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('Capture only what is necessary (POPIA).', style: TextStyle(fontSize: 11, color: AppColors.secondaryText))),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, nameC.text.trim().isEmpty ? null : Witness(name: nameC.text.trim(), contact: contactC.text.trim(), statement: stmtC.text.trim())), child: const Text('Add')),
        ],
      ),
    );
    if (w != null) setState(() => _witnesses.add(w));
  }

  Future<void> _addMedia() async {
    final media = await showModalBottomSheet<CapturedMedia?>(
      context: context,
      builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'), onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).capturePhoto()); }),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose image'), onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).pickImage()); }),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choose PDF'), onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).pickPdf()); }),
      ],),),
    );
    if (media != null) setState(() => _media.add(media));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final params = ReportIncidentParams(
      type: _type, severity: _severity, occurredAt: _occurredAt,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      locationText: _location.text.trim().isEmpty ? null : _location.text.trim(),
      latitude: _gps?.latitude, longitude: _gps?.longitude, witnesses: _witnesses,
    );
    final incident = await ref.read(incidentReportControllerProvider.notifier).submit(params);
    if (!mounted) return;
    if (incident == null) {
      final f = ref.read(incidentReportControllerProvider).error;
      _snack(f is Failure ? f.message : 'Could not save incident');
      return;
    }
    final owner = (type: AttachmentOwnerType.incident, id: incident.id);
    for (final m in _media) {
      await ref.read(attachmentControllerProvider.notifier).add(owner: owner, media: m);
    }
    if (!mounted) return;
    _snack('Incident reported');
    context.pop();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(incidentReportControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Report incident')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            DropdownButtonFormField<IncidentType>(
              initialValue: _type, decoration: const InputDecoration(labelText: 'Type *'),
              items: [for (final t in IncidentType.values) DropdownMenuItem(value: t, child: Text(t.label))],
              onChanged: (v) => setState(() => _type = v ?? IncidentType.nearMiss),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<IncidentSeverity>(
              initialValue: _severity, decoration: const InputDecoration(labelText: 'Severity *'),
              items: [for (final s in IncidentSeverity.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _severity = v ?? IncidentSeverity.minor),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Occurred at'),
              subtitle: Text(DateFormat.yMMMd().add_jm().format(_occurredAt)),
              trailing: const Icon(Icons.event_outlined),
              onTap: _pickDateTime,
            ),
            TextFormField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location note')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final g = await ref.read(mediaCaptureServiceProvider).currentGps();
                if (mounted) setState(() => _gps = g);
              },
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(_gps == null ? 'Capture GPS' : 'GPS captured'),
            ),
            const SizedBox(height: 16),
            _sectionHeader('Witnesses', _addWitness),
            if (_witnesses.isEmpty) const Text('None', style: TextStyle(color: AppColors.secondaryText)),
            for (var i = 0; i < _witnesses.length; i++)
              Chip(label: Text(_witnesses[i].name), onDeleted: () => setState(() => _witnesses.removeAt(i))),
            const SizedBox(height: 16),
            _sectionHeader('Photos & evidence', _addMedia),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < _media.length; i++)
                Chip(label: Text(_media[i].fileName, overflow: TextOverflow.ellipsis), onDeleted: () => setState(() => _media.removeAt(i))),
            ],),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : _submit,
              child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit incident'),
            ),
          ],),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onAdd) => Row(children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Add')),
      ],);
}
