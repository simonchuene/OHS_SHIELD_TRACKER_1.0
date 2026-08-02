// path: lib/features/attachments/domain/attachment_constants.dart
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';

/// Attachment limits & allowed formats (Master Prompt ATTACHMENT MANAGEMENT:
/// max 20 MB; JPG/PNG/PDF). Mirrors the DB CHECK constraints (0004).
abstract final class AttachmentLimits {
  static const int maxBytes = 20 * 1024 * 1024; // 20 MB

  static const Map<String, String> allowedExtByType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'application/pdf': 'pdf',
  };

  static bool isAllowedType(String contentType) => allowedExtByType.containsKey(contentType);
  static String? extensionFor(String contentType) => allowedExtByType[contentType];
}

/// Storage path convention — MUST match the Storage RLS policy (0008):
/// `<company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>`.
abstract final class AttachmentPaths {
  static String build({
    required String companyId,
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required String versionId,
    required String contentType,
  }) {
    final ext = AttachmentLimits.extensionFor(contentType) ?? 'bin';
    return '$companyId/${ownerType.dbValue}/$ownerId/$versionId.$ext';
  }
}

/// Pure client-side validation. Returns null when valid, else an error message.
abstract final class AttachmentValidator {
  static String? validate({required String contentType, required int sizeBytes}) {
    if (!AttachmentLimits.isAllowedType(contentType)) {
      return 'Only JPG, PNG, and PDF files are allowed.';
    }
    if (sizeBytes <= 0) return 'The file appears to be empty.';
    if (sizeBytes > AttachmentLimits.maxBytes) {
      return 'Files must be 20 MB or smaller.';
    }
    return null;
  }
}
