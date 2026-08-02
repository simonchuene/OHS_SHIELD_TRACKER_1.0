// path: lib/features/attachments/domain/entities/gps_location.dart
/// A captured GPS point (Mobile Experience: GPS Capture). Attached as metadata
/// to hazards/incidents/inspections and to media captures.
class GpsLocation {
  const GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final double? accuracy;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'captured_at': capturedAt.toIso8601String(),
        'accuracy': accuracy,
      };

  @override
  String toString() => '($latitude, $longitude)';
}

/// A file selected/captured on-device, ready to upload.
class CapturedMedia {
  const CapturedMedia({
    required this.localPath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.gps,
  });

  final String localPath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final GpsLocation? gps;
}
