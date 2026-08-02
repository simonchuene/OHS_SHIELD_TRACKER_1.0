// path: lib/features/incidents/domain/entities/incident.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/witness.dart';

part 'incident.freezed.dart';

/// A first-class incident (separate entity from Hazard — Domain Model Rule).
@freezed
class Incident with _$Incident {
  const Incident._();

  const factory Incident({
    required String id,
    required String companyId,
    String? siteId,
    String? departmentId,
    String? reference,
    required IncidentType type,
    required IncidentSeverity severity,
    @Default(IncidentStatus.reported) IncidentStatus status,
    required DateTime occurredAt,
    String? locationText,
    double? latitude,
    double? longitude,
    String? description,
    @Default(<Witness>[]) List<Witness> witnesses,
    String? sourceHazardId,
    required String reporterId,
    DateTime? closedAt,
    @Default(0) int version,
  }) = _Incident;

  bool get isClosed => status.isClosed;
  bool get hasLocation => latitude != null && longitude != null;
  bool get isLinkedToHazard => sourceHazardId != null;
}
