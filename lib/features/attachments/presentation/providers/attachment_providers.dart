// path: lib/features/attachments/presentation/providers/attachment_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/attachments/application/attachment_use_cases.dart';
import 'package:ohs_shield_tracker/features/attachments/data/attachment_repository_impl.dart';
import 'package:ohs_shield_tracker/features/attachments/data/attachment_upload_queue.dart';
import 'package:ohs_shield_tracker/features/attachments/data/media_capture_service.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/repositories/attachment_repository.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attachment_providers.g.dart';

/// Owner reference used as a family key for an owner's attachment list.
typedef OwnerRef = ({AttachmentOwnerType type, String id});

@riverpod
AttachmentRepository attachmentRepository(AttachmentRepositoryRef ref) =>
    AttachmentRepositoryImpl(ref.watch(supabaseClientProvider), ref.watch(loggerProvider));

@riverpod
AttachmentUseCases attachmentUseCases(AttachmentUseCasesRef ref) =>
    AttachmentUseCases(ref.watch(attachmentRepositoryProvider));

@riverpod
MediaCaptureService mediaCaptureService(MediaCaptureServiceRef ref) =>
    MediaCaptureService(ref.watch(loggerProvider));

@riverpod
AttachmentUploadQueue attachmentUploadQueue(AttachmentUploadQueueRef ref) {
  final queue = AttachmentUploadQueue(
    db: ref.watch(appDatabaseProvider),
    repo: ref.watch(attachmentRepositoryProvider),
    logger: ref.watch(loggerProvider),
  );
  queue.start(ref.watch(connectivityStatusProvider.stream));
  ref.onDispose(queue.dispose);
  return queue;
}

@riverpod
Future<List<Attachment>> ownerAttachments(OwnerAttachmentsRef ref, OwnerRef owner) async {
  final res = await ref.watch(attachmentUseCasesProvider).listForOwner(owner.type, owner.id);
  return res.when(ok: (a) => a, err: (f) => throw f);
}

@riverpod
Future<List<AttachmentVersion>> attachmentVersions(AttachmentVersionsRef ref, String attachmentId) async {
  final res = await ref.watch(attachmentUseCasesProvider).listVersions(attachmentId);
  return res.when(ok: (v) => v, err: (f) => throw f);
}

/// Count of uploads waiting to sync (for the offline banner / badges).
@riverpod
Stream<int> pendingUploadCount(PendingUploadCountRef ref) =>
    ref.watch(appDatabaseProvider).watchPendingUploadCount();

/// Adds/deletes attachments; uploads directly when online, otherwise queues.
@riverpod
class AttachmentController extends _$AttachmentController {
  @override
  FutureOr<void> build() {}

  /// Returns true on success (uploaded or queued), false on validation/other error.
  Future<bool> add({
    required OwnerRef owner,
    required CapturedMedia media,
    String? attachmentId,
  }) async {
    state = const AsyncLoading();
    final online = ref.read(connectivityStatusProvider).valueOrNull ?? true;

    if (!online) {
      final companyId = await _companyId();
      if (companyId == null) {
        state = AsyncError(StateError('No company'), StackTrace.current);
        return false;
      }
      await ref.read(attachmentUploadQueueProvider).enqueue(
            media: media, ownerType: owner.type, ownerId: owner.id,
            companyId: companyId, uploadedBy: _uid, attachmentId: attachmentId,
          );
      state = const AsyncData(null);
      ref.invalidate(ownerAttachmentsProvider(owner)); // (queued items surface once synced)
      return true;
    }

    final res = await ref.read(attachmentUseCasesProvider).upload(
          ownerType: owner.type, ownerId: owner.id, media: media, attachmentId: attachmentId,
        );
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        ref.invalidate(ownerAttachmentsProvider(owner));
        if (attachmentId != null) ref.invalidate(attachmentVersionsProvider(attachmentId));
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> remove({required OwnerRef owner, required String attachmentId}) async {
    state = const AsyncLoading();
    final res = await ref.read(attachmentUseCasesProvider).delete(attachmentId);
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        ref.invalidate(ownerAttachmentsProvider(owner));
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  String? get _uid => ref.read(supabaseClientProvider).auth.currentUser?.id;

  Future<String?> _companyId() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await ref
        .read(supabaseClientProvider)
        .from('user_profiles')
        .select('company_id')
        .eq('user_id', uid)
        .maybeSingle();
    return row?['company_id'] as String?;
  }
}
