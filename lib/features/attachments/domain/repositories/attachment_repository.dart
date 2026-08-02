// path: lib/features/attachments/domain/repositories/attachment_repository.dart
import 'dart:typed_data';

import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';

/// Single upload/preview API surface consumed by all feature modules
/// (Hazard/Incident/Investigation/CAPA/Inspection). See Ledger §3.
abstract interface class AttachmentRepository {
  /// Upload a new file for an owner (creates the [Attachment] + version 1),
  /// or a new revision when [attachmentId] is supplied (adds a version and
  /// marks prior versions inactive — never deletes history).
  Future<Result<Attachment>> upload({
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required String localPath,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    String? attachmentId,
  });

  /// All active attachments for a business record.
  Future<Result<List<Attachment>>> listForOwner(
      AttachmentOwnerType ownerType, String ownerId,);

  /// Full version history for one attachment (newest first), including inactive.
  Future<Result<List<AttachmentVersion>>> listVersions(String attachmentId);

  /// A time-limited signed URL for previewing the active (or a specific) version.
  Future<Result<String>> preview(String attachmentId, {String? versionId});

  /// Download the active (or a specific) version's bytes.
  Future<Result<Uint8List>> download(String attachmentId, {String? versionId});

  /// Logical delete — marks the attachment inactive. Version history is retained.
  Future<Result<void>> delete(String attachmentId);
}
