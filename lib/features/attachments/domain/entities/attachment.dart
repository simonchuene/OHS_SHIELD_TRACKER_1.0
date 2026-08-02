// path: lib/features/attachments/domain/entities/attachment.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';

part 'attachment.freezed.dart';

/// A logical attachment (one file identity) belonging to a business record.
/// Its bytes are stored across one-or-more [AttachmentVersion]s; the active
/// version is the current file.
@freezed
class Attachment with _$Attachment {
  const Attachment._();

  const factory Attachment({
    required String id,
    required String companyId,
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required String fileName,
    required String contentType,
    @Default(true) bool isActive,
    String? createdBy,
    required DateTime createdAt,
    @Default(1) int versionCount,
  }) = _Attachment;

  bool get isImage => contentType == 'image/jpeg' || contentType == 'image/png';
  bool get isPdf => contentType == 'application/pdf';
}

/// One uploaded revision of an [Attachment]. Superseded versions are marked
/// inactive (never deleted) — app-layer version history (Supabase Storage has none).
@freezed
class AttachmentVersion with _$AttachmentVersion {
  const AttachmentVersion._();

  const factory AttachmentVersion({
    required String id,
    required String attachmentId,
    required String companyId,
    required int versionNo,
    required String storagePath,
    required int fileSize,
    required String contentType,
    @Default(true) bool isActive,
    String? uploadedBy,
    required DateTime createdAt,
  }) = _AttachmentVersion;
}
