// path: lib/features/incidents/data/incident_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/witness.dart';

part 'incident_dto.freezed.dart';
part 'incident_dto.g.dart';

/// PostgREST / local-cache row for `incidents`.
@freezed
class IncidentDto with _$IncidentDto {
  const IncidentDto._();

  const factory IncidentDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'department_id') String? departmentId,
    String? reference,
    @JsonKey(name: 'incident_type') required String incidentType,
    required String severity,
    @Default('reported') String status,
    @JsonKey(name: 'occurred_at') required String occurredAt,
    @JsonKey(name: 'location_text') String? locationText,
    double? latitude,
    double? longitude,
    String? description,
    @Default(<dynamic>[]) List<dynamic> witnesses,
    @JsonKey(name: 'source_hazard_id') String? sourceHazardId,
    @JsonKey(name: 'reporter_id') required String reporterId,
    @JsonKey(name: 'closed_at') String? closedAt,
    @Default(0) int version,
  }) = _IncidentDto;

  factory IncidentDto.fromJson(Map<String, dynamic> json) => _$IncidentDtoFromJson(json);

  Incident toEntity() => Incident(
        id: id,
        companyId: companyId,
        siteId: siteId,
        departmentId: departmentId,
        reference: reference,
        type: IncidentType.fromDb(incidentType),
        severity: IncidentSeverity.fromDb(severity),
        status: IncidentStatus.fromDb(status),
        occurredAt: DateTime.parse(occurredAt),
        locationText: locationText,
        latitude: latitude,
        longitude: longitude,
        description: description,
        witnesses: [
          for (final w in witnesses)
            if (w is Map) Witness.fromJson(Map<String, dynamic>.from(w)),
        ],
        sourceHazardId: sourceHazardId,
        reporterId: reporterId,
        closedAt: closedAt != null ? DateTime.tryParse(closedAt!) : null,
        version: version,
      );
}
