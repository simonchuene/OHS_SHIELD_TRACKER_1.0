// path: lib/features/attachments/data/attachment_upload_queue.dart
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/attachment_owner_type.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/repositories/attachment_repository.dart';
import 'package:ohs_shield_tracker/services/sync/retry_policy.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Offline queue for attachment uploads (Master Prompt: "Offline queuing for
/// uploads made without connectivity"). Persists the file locally, then drains
/// through [AttachmentRepository] when connectivity returns (D5 backoff reused).
class AttachmentUploadQueue {
  AttachmentUploadQueue({
    required AppDatabase db,
    required AttachmentRepository repo,
    required LoggerService logger,
    this.retry = const RetryPolicy(),
    Uuid uuid = const Uuid(),
  })  : _db = db,
        _repo = repo,
        _logger = logger,
        _uuid = uuid;

  final AppDatabase _db;
  final AttachmentRepository _repo;
  final LoggerService _logger;
  final RetryPolicy retry;
  final Uuid _uuid;

  StreamSubscription<bool>? _sub;
  bool _running = false;

  void start(Stream<bool> connectivity) {
    _sub = connectivity.listen((online) {
      if (online) unawaited(drain());
    });
    unawaited(drain()); // initial attempt at launch
  }

  Future<void> dispose() async => _sub?.cancel();

  /// Copy the file to persistent storage and queue it (survives cache eviction).
  Future<void> enqueue({
    required CapturedMedia media,
    required AttachmentOwnerType ownerType,
    required String ownerId,
    required String companyId,
    String? uploadedBy,
    String? attachmentId,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final uploadsDir = Directory(p.join(dir.path, 'pending_uploads'))..createSync(recursive: true);
    final persisted = p.join(uploadsDir.path, '${_uuid.v4()}${p.extension(media.localPath)}');
    await File(media.localPath).copy(persisted);

    await _db.enqueuePendingUpload(PendingUploadsCompanion(
      id: Value(_uuid.v4()),
      companyId: Value(companyId),
      ownerType: Value(ownerType.dbValue),
      ownerId: Value(ownerId),
      attachmentId: Value(attachmentId),
      localPath: Value(persisted),
      fileName: Value(media.fileName),
      contentType: Value(media.contentType),
      sizeBytes: Value(media.sizeBytes),
      uploadedBy: Value(uploadedBy),
      gpsLat: Value(media.gps?.latitude),
      gpsLng: Value(media.gps?.longitude),
    ),);
  }

  Future<void> drain() async {
    if (_running) return;
    _running = true;
    try {
      final due = await _db.duePendingUploads(DateTime.now());
      for (final row in due) {
        await _process(row);
      }
    } catch (e, s) {
      _logger.error('Attachment queue drain failed', e, s);
    } finally {
      _running = false;
    }
  }

  Future<void> _process(PendingUpload row) async {
    final result = await _repo.upload(
      ownerType: AttachmentOwnerType.fromDb(row.ownerType),
      ownerId: row.ownerId,
      localPath: row.localPath,
      fileName: row.fileName,
      contentType: row.contentType,
      sizeBytes: row.sizeBytes,
      attachmentId: row.attachmentId,
    );

    await result.when(
      ok: (_) async {
        await _db.deletePendingUpload(row.id);
        final f = File(row.localPath);
        if (f.existsSync()) await f.delete();
        _logger.info('Queued upload synced (${row.ownerType}/${row.ownerId})');
      },
      err: (failure) async {
        final attempts = row.attempts + 1;
        final patch = retry.hasAttemptsLeft(attempts)
            ? PendingUploadsCompanion(
                attempts: Value(attempts),
                nextAttemptAt: Value(DateTime.now().add(retry.delayForAttempt(attempts))),
                lastError: Value(failure.message),
              )
            : PendingUploadsCompanion(attempts: Value(attempts), lastError: Value(failure.message));
        await _db.updatePendingUpload(row.id, patch);
        _logger.warn('Queued upload retry #$attempts: ${failure.message}');
      },
    );
  }
}
