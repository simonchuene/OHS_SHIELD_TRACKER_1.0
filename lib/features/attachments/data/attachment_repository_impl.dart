// path: lib/features/attachments/data/attachment_repository_impl.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/attachments/data/attachment_dtos.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/attachment_constants.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/repositories/attachment_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _bucket = 'attachments';

final class AttachmentRepositoryImpl extends BaseRepository implements AttachmentRepository {
  AttachmentRepositoryImpl(this._client, LoggerService logger, {Uuid uuid = const Uuid()})
      : _uuid = uuid,
        super(logger);

  final SupabaseClient _client;
  final Uuid _uuid;
  String? _companyIdCache;

  @override
  Future<Result<Attachment>> upload({
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required String localPath,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    String? attachmentId,
  }) {
    return run<Attachment>(() async {
      // Size/type are validated in UploadAttachmentUseCase before we reach here.
      final companyId = await _companyId();
      final uploaderId = _client.auth.currentUser?.id;
      final bytes = await File(localPath).readAsBytes();

      final versionId = _uuid.v4();
      final storagePath = AttachmentPaths.build(
        companyId: companyId, ownerType: ownerType, ownerId: ownerId,
        versionId: versionId, contentType: contentType,
      );
      await _client.storage.from(_bucket).uploadBinary(
            storagePath, bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      if (attachmentId == null) {
        final attId = _uuid.v4();
        final attRow = await _client.from('attachments').insert({
          'id': attId, 'company_id': companyId, 'owner_type': ownerType.dbValue,
          'owner_id': ownerId, 'file_name': fileName, 'content_type': contentType,
          'created_by': uploaderId,
        }).select().single();
        await _client.from('attachment_versions').insert({
          'id': versionId, 'attachment_id': attId, 'company_id': companyId,
          'version_no': 1, 'storage_path': storagePath, 'file_size': sizeBytes,
          'content_type': contentType, 'is_active': true, 'uploaded_by': uploaderId,
        });
        return AttachmentDto.fromJson(attRow).toEntity(versionCount: 1);
      }

      // New revision of an existing attachment: supersede prior versions.
      await _client.from('attachment_versions').update({'is_active': false}).eq('attachment_id', attachmentId);
      final maxRows = await _client
          .from('attachment_versions').select('version_no')
          .eq('attachment_id', attachmentId).order('version_no', ascending: false).limit(1);
      final nextNo = maxRows.isEmpty ? 1 : (maxRows.first['version_no'] as int) + 1;
      await _client.from('attachment_versions').insert({
        'id': versionId, 'attachment_id': attachmentId, 'company_id': companyId,
        'version_no': nextNo, 'storage_path': storagePath, 'file_size': sizeBytes,
        'content_type': contentType, 'is_active': true, 'uploaded_by': uploaderId,
      });
      final attRow = await _client.from('attachments')
          .update({'file_name': fileName, 'content_type': contentType})
          .eq('id', attachmentId).select().single();
      return AttachmentDto.fromJson(attRow).toEntity(versionCount: nextNo);
    }, context: 'upload',);
  }

  @override
  Future<Result<List<Attachment>>> listForOwner(AttachmentOwnerType ownerType, String ownerId) {
    return run(() async {
      final rows = await _client.from('attachments')
          .select('*, attachment_versions(id)')
          .eq('owner_type', ownerType.dbValue).eq('owner_id', ownerId)
          .eq('is_active', true).order('created_at');
      return [
        for (final r in rows)
          AttachmentDto.fromJson(r).toEntity(
            versionCount: ((r['attachment_versions'] as List?)?.length ?? 1),
          ),
      ];
    }, context: 'listForOwner',);
  }

  @override
  Future<Result<List<AttachmentVersion>>> listVersions(String attachmentId) {
    return run(() async {
      final rows = await _client.from('attachment_versions')
          .select().eq('attachment_id', attachmentId).order('version_no', ascending: false);
      return [for (final r in rows) AttachmentVersionDto.fromJson(r).toEntity()];
    }, context: 'listVersions',);
  }

  @override
  Future<Result<String>> preview(String attachmentId, {String? versionId}) {
    return run(() async {
      final path = await _resolvePath(attachmentId, versionId);
      return _client.storage.from(_bucket).createSignedUrl(path, 3600); // 1h
    }, context: 'preview',);
  }

  @override
  Future<Result<Uint8List>> download(String attachmentId, {String? versionId}) {
    return run(() async {
      final path = await _resolvePath(attachmentId, versionId);
      return _client.storage.from(_bucket).download(path);
    }, context: 'download',);
  }

  @override
  Future<Result<void>> delete(String attachmentId) {
    // Logical delete only — version history is retained (never destroyed).
    return run(() async {
      await _client.from('attachments').update({'is_active': false}).eq('id', attachmentId);
    }, context: 'delete',);
  }

  Future<String> _resolvePath(String attachmentId, String? versionId) async {
    final query = _client.from('attachment_versions').select('storage_path');
    final rows = versionId != null
        ? await query.eq('id', versionId).limit(1)
        : await query.eq('attachment_id', attachmentId).eq('is_active', true)
            .order('version_no', ascending: false).limit(1);
    if (rows.isEmpty) throw const _NotFoundSignal('No file version found.');
    return rows.first['storage_path'] as String;
  }

  Future<String> _companyId() async {
    if (_companyIdCache != null) return _companyIdCache!;
    final uid = _client.auth.currentUser?.id;
    final row = await _client.from('user_profiles').select('company_id').eq('user_id', uid!).single();
    return _companyIdCache = row['company_id'] as String;
  }
}

/// Internal signal mapped to a Failure by guardAsync's catch-all (kept private).
class _NotFoundSignal implements Exception {
  const _NotFoundSignal(this.message);
  final String message;
  @override
  String toString() => message;
}
