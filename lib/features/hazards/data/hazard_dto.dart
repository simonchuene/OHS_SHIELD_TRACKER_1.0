// path: lib/features/hazards/data/hazard_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

part 'hazard_dto.freezed.dart';
part 'hazard_dto.g.dart';

/// PostgREST/local-cache row for `hazards`. Works for both server rows and the
/// snake_case payloads written to the offline cache.
@freezed
class HazardDto with _$HazardDto {
  const HazardDto._();

  const factory HazardDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'department_id') String? departmentId,
    String? reference,
    required String title,
    String? description,
    required String category,
    @Default('draft') String status,
    @JsonKey(name: 'risk_level') String? riskLevel,
    @JsonKey(name: 'reporter_id') required String reporterId,
    double? latitude,
    double? longitude,
    @JsonKey(name: 'location_text') String? locationText,
    @JsonKey(name: 'source_incident_id') String? sourceIncidentId,
    @JsonKey(name: 'reported_at') String? reportedAt,
    @Default(0) int version,
  }) = _HazardDto;

  factory HazardDto.fromJson(Map<String, dynamic> json) => _$HazardDtoFromJson(json);

  Hazard toEntity() => Hazard(
        id: id,
        companyId: companyId,
        siteId: siteId,
        departmentId: departmentId,
        reference: reference,
        title: title,
        description: description,
        category: HazardCategory.fromDb(category),
        status: HazardStatus.fromDb(status),
        riskLevel: RiskBand.fromDb(riskLevel),
        reporterId: reporterId,
        latitude: latitude,
        longitude: longitude,
        locationText: locationText,
        sourceIncidentId: sourceIncidentId,
        reportedAt: reportedAt != null ? DateTime.parse(reportedAt!) : DateTime.now(),
        version: version,
      );
}
