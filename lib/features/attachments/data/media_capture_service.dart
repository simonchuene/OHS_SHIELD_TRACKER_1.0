// path: lib/features/attachments/data/media_capture_service.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/attachments/domain/entities/gps_location.dart';
import 'package:path/path.dart' as p;

/// Reusable camera / gallery / file + GPS capture (Master Prompt Mobile
/// Experience: Camera Uploads, GPS Capture). Shared across Hazard/Incident/
/// Inspection forms via the AttachmentField widget.
class MediaCaptureService {
  MediaCaptureService(this._logger, {ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final LoggerService _logger;

  Future<CapturedMedia?> capturePhoto({bool withGps = true}) async =>
      _fromXFile(await _picker.pickImage(source: ImageSource.camera, imageQuality: 85), withGps: withGps);

  Future<CapturedMedia?> pickImage({bool withGps = false}) async =>
      _fromXFile(await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85), withGps: withGps);

  Future<CapturedMedia?> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.files.single.path;
    if (path == null) return null;
    return _capturedFrom(path, gps: null);
  }

  Future<CapturedMedia?> _fromXFile(XFile? file, {required bool withGps}) async {
    if (file == null) return null;
    final gps = withGps ? await currentGps() : null;
    return _capturedFrom(file.path, gps: gps, name: file.name);
  }

  Future<CapturedMedia> _capturedFrom(String path, {GpsLocation? gps, String? name}) async {
    final f = File(path);
    return CapturedMedia(
      localPath: path,
      fileName: name ?? p.basename(path),
      contentType: _contentType(path),
      sizeBytes: await f.length(),
      gps: gps,
    );
  }

  /// Best-effort current location. Returns null if permission denied / unavailable
  /// (GPS is optional metadata, never a blocker for capture).
  Future<GpsLocation?> currentGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition();
      return GpsLocation(
        latitude: pos.latitude, longitude: pos.longitude,
        accuracy: pos.accuracy, capturedAt: DateTime.now(),
      );
    } catch (e, s) {
      _logger.warn('GPS capture failed', e, s);
      return null;
    }
  }

  String _contentType(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
