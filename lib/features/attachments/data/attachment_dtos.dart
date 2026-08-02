// path: lib/features/attachments/data/attachment_dtos.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';

part 'attachment_dtos.freezed.dart';
part 'attachment_dtos.g.dart';

@freezed
class AttachmentDto with _$AttachmentDto {
  const AttachmentDto._();
  const factory AttachmentDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'owner_type') required String ownerType,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _AttachmentDto;

  factory AttachmentDto.fromJson(Map<String, dynamic> json) => _$AttachmentDtoFromJson(json);

  Attachment toEntity({int versionCount = 1}) => Attachment(
        id: id,
        companyId: companyId,
        ownerType: AttachmentOwnerType.fromDb(ownerType),
        ownerId: ownerId,
        fileName: fileName,
        contentType: contentType,
        isActive: isActive,
        createdBy: createdBy,
        createdAt: DateTime.parse(createdAt),
        versionCount: versionCount,
      );
}

@freezed
class AttachmentVersionDto with _$AttachmentVersionDto {
  const AttachmentVersionDto._();
  const factory AttachmentVersionDto({
    required String id,
    @JsonKey(name: 'attachment_id') required String attachmentId,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'version_no') required int versionNo,
    @JsonKey(name: 'storage_path') required String storagePath,
    @JsonKey(name: 'file_size') required int fileSize,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'uploaded_by') String? uploadedBy,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _AttachmentVersionDto;

  factory AttachmentVersionDto.fromJson(Map<String, dynamic> json) =>
      _$AttachmentVersionDtoFromJson(json);

  AttachmentVersion toEntity() => AttachmentVersion(
        id: id,
        attachmentId: attachmentId,
        companyId: companyId,
        versionNo: versionNo,
        storagePath: storagePath,
        fileSize: fileSize,
        contentType: contentType,
        isActive: isActive,
        uploadedBy: uploadedBy,
        createdAt: DateTime.parse(createdAt),
      );
}
