// path: lib/features/attachments/presentation/widgets/attachment_field.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/presentation/providers/attachment_providers.dart';

/// The single reusable attachment component consumed by Hazard/Incident/
/// Investigation/CAPA/Inspection forms. Embed with the owner ref; it handles
/// capture (camera/gallery/PDF + GPS), upload (online or queued), preview,
/// delete, and version history.
class AttachmentField extends ConsumerWidget {
  const AttachmentField({
    required this.ownerType,
    required this.ownerId,
    this.editable = true,
    this.title = 'Attachments',
    super.key,
  });

  final AttachmentOwnerType ownerType;
  final String ownerId;
  final bool editable;
  final String title;

  OwnerRef get _owner => (type: ownerType, id: ownerId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerAttachmentsProvider(_owner));
    final busy = ref.watch(attachmentControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (editable)
              TextButton.icon(
                onPressed: busy ? null : () => _showAddSheet(context, ref),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          error: (e, _) => Text('Could not load attachments', style: Theme.of(context).textTheme.labelSmall),
          data: (items) => items.isEmpty
              ? Text('No attachments yet', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final a in items) _AttachmentTile(attachment: a, owner: _owner, editable: editable)],
                ),
        ),
      ],
    );
  }

  Future<void> _showAddSheet(BuildContext context, WidgetRef ref) async {
    final media = await showModalBottomSheet<CapturedMedia?>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () async {
                final nav = Navigator.of(c);
                nav.pop(await ref.read(mediaCaptureServiceProvider).capturePhoto());
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose image'),
              onTap: () async {
                final nav = Navigator.of(c);
                nav.pop(await ref.read(mediaCaptureServiceProvider).pickImage());
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose PDF'),
              onTap: () async {
                final nav = Navigator.of(c);
                nav.pop(await ref.read(mediaCaptureServiceProvider).pickPdf());
              },
            ),
          ],
        ),
      ),
    );
    if (media == null || !context.mounted) return;

    final ok = await ref.read(attachmentControllerProvider.notifier).add(owner: _owner, media: media);
    if (!context.mounted) return;
    final err = ref.read(attachmentControllerProvider).error;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ok ? 'Attachment saved' : 'Upload failed: ${err ?? ''}')));
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment, required this.owner, required this.editable});
  final Attachment attachment;
  final OwnerRef owner;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _preview(context, ref),
      onLongPress: editable ? () => _confirmDelete(context, ref) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(attachment.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: AppColors.infoBlue, size: 32,),
            const SizedBox(height: 6),
            Text(attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,),
            if (attachment.versionCount > 1)
              Text('v${attachment.versionCount}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(attachmentUseCasesProvider).preview(attachment.id);
    if (!context.mounted) return;
    res.when(
      ok: (url) => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: attachment.isImage
              ? Image.network(url, fit: BoxFit.contain)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 48, color: AppColors.criticalRed),
                    const SizedBox(height: 12),
                    Text(attachment.fileName),
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
                  ],),
                ),
        ),
      ),
      err: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text('${attachment.fileName} will be hidden. Version history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(attachmentControllerProvider.notifier).remove(owner: owner, attachmentId: attachment.id);
  }
}
