// path: lib/features/incidents/domain/entities/incident_filter.dart
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/witness.dart';

class IncidentFilter {
  const IncidentFilter({this.status, this.severity, this.type, this.siteId, this.query, this.mineOnly = false});
  final IncidentStatus? status;
  final IncidentSeverity? severity;
  final IncidentType? type;
  final String? siteId;
  final String? query;
  final bool mineOnly;

  IncidentFilter copyWith({
    IncidentStatus? status,
    IncidentSeverity? severity,
    IncidentType? type,
    String? siteId,
    String? query,
    bool? mineOnly,
    bool clearStatus = false,
    bool clearSeverity = false,
  }) =>
      IncidentFilter(
        status: clearStatus ? null : (status ?? this.status),
        severity: clearSeverity ? null : (severity ?? this.severity),
        type: type ?? this.type,
        siteId: siteId ?? this.siteId,
        query: query ?? this.query,
        mineOnly: mineOnly ?? this.mineOnly,
      );
}

class ReportIncidentParams {
  const ReportIncidentParams({
    required this.type,
    required this.severity,
    required this.occurredAt,
    this.description,
    this.locationText,
    this.latitude,
    this.longitude,
    this.witnesses = const [],
    this.siteId,
    this.departmentId,
    this.sourceHazardId,
  });

  final IncidentType type;
  final IncidentSeverity severity;
  final DateTime occurredAt;
  final String? description;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final List<Witness> witnesses;
  final String? siteId;
  final String? departmentId;
  final String? sourceHazardId;
}
