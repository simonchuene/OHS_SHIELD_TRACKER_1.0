// path: lib/features/hazards/presentation/screens/hazard_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/core/utils/validators.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/providers/attachment_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';

/// Report a hazard — quick field capture (Master Prompt: fast data capture),
/// GPS + photos via the shared attachment service.
class HazardReportScreen extends ConsumerStatefulWidget {
  const HazardReportScreen({super.key});
  @override
  ConsumerState<HazardReportScreen> createState() => _HazardReportScreenState();
}

class _HazardReportScreenState extends ConsumerState<HazardReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  HazardCategory _category = HazardCategory.physical;
  GpsLocation? _gps;
  final _media = <CapturedMedia>[];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    final gps = await ref.read(mediaCaptureServiceProvider).currentGps();
    if (!mounted) return;
    setState(() => _gps = gps);
    _snack(gps == null ? 'Location unavailable' : 'Location captured');
  }

  Future<void> _addMedia() async {
    final media = await showModalBottomSheet<CapturedMedia?>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'),
              onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).capturePhoto()); },),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose image'),
              onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).pickImage()); },),
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Choose PDF'),
              onTap: () async { final n = Navigator.of(c); n.pop(await ref.read(mediaCaptureServiceProvider).pickPdf()); },),
        ],),
      ),
    );
    if (media != null) setState(() => _media.add(media));
  }

  Future<void> _submit({required bool submitNow}) async {
    if (!_formKey.currentState!.validate()) return;
    final params = ReportHazardParams(
      title: _title.text.trim(),
      category: _category,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      latitude: _gps?.latitude,
      longitude: _gps?.longitude,
      locationText: _location.text.trim().isEmpty ? null : _location.text.trim(),
      submitNow: submitNow,
    );

    final hazard = await ref.read(hazardReportControllerProvider.notifier).submit(params);
    if (!mounted) return;
    if (hazard == null) {
      final f = ref.read(hazardReportControllerProvider).error;
      _snack(f is Failure ? f.message : 'Could not save hazard');
      return;
    }
    // Upload captured media against the new hazard (queued if offline).
    final owner = (type: AttachmentOwnerType.hazard, id: hazard.id);
    for (final m in _media) {
      await ref.read(attachmentControllerProvider.notifier).add(owner: owner, media: m);
    }
    if (!mounted) return;
    _snack(submitNow ? 'Hazard reported' : 'Draft saved');
    context.pop();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(hazardReportControllerProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Report hazard')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *', hintText: 'Short description of the hazard'),
              maxLength: 120,
              validator: (v) => Validators.required(v, field: 'Title'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<HazardCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: [for (final c in HazardCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: (v) => setState(() => _category = v ?? HazardCategory.physical),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location note')),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _captureGps,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: Text(_gps == null ? 'Capture GPS' : 'GPS: ${_gps!.latitude.toStringAsFixed(4)}, ${_gps!.longitude.toStringAsFixed(4)}'),
              ),
            ],),
            const SizedBox(height: 16),
            Row(children: [
              Text('Photos & evidence', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton.icon(onPressed: _addMedia, icon: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Add')),
            ],),
            if (_media.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _media.length; i++)
                  Chip(
                    label: Text(_media[i].fileName, overflow: TextOverflow.ellipsis),
                    onDeleted: () => setState(() => _media.removeAt(i)),
                  ),
              ],)
            else
              Text('No files added', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : () => _submit(submitNow: true),
              child: busy
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit hazard'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: busy ? null : () => _submit(submitNow: false), child: const Text('Save as draft')),
          ],),
        ),
      ),
    );
  }
}
