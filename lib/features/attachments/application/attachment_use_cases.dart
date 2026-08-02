// path: lib/features/attachments/application/attachment_use_cases.dart
import 'dart:typed_data';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/attachment_constants.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/repositories/attachment_repository.dart';

/// Application facade for the shared attachment service — the single API surface
/// downstream modules call (Ledger §3).
class AttachmentUseCases {
  const AttachmentUseCases(this._repo);
  final AttachmentRepository _repo;

  /// Validate (20 MB / JPG-PNG-PDF) then upload — new file or new revision.
  Future<Result<Attachment>> upload({
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required CapturedMedia media,
    String? attachmentId,
  }) {
    final error = AttachmentValidator.validate(contentType: media.contentType, sizeBytes: media.sizeBytes);
    if (error != null) {
      return Future.value(Err(ValidationFailure(error)));
    }
    return _repo.upload(
      ownerType: ownerType, ownerId: ownerId, localPath: media.localPath,
      fileName: media.fileName, contentType: media.contentType,
      sizeBytes: media.sizeBytes, attachmentId: attachmentId,
    );
  }

  Future<Result<List<Attachment>>> listForOwner(AttachmentOwnerType t, String id) =>
      _repo.listForOwner(t, id);
  Future<Result<List<AttachmentVersion>>> listVersions(String attachmentId) =>
      _repo.listVersions(attachmentId);
  Future<Result<String>> preview(String attachmentId, {String? versionId}) =>
      _repo.preview(attachmentId, versionId: versionId);
  Future<Result<Uint8List>> download(String attachmentId, {String? versionId}) =>
      _repo.download(attachmentId, versionId: versionId);
  Future<Result<void>> delete(String attachmentId) => _repo.delete(attachmentId);
}
