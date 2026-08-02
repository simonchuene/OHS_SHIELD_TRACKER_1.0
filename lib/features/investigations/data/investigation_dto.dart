// path: lib/features/investigations/data/investigation_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';

part 'investigation_dto.freezed.dart';
part 'investigation_dto.g.dart';

@freezed
class InvestigationDto with _$InvestigationDto {
  const InvestigationDto._();

  const factory InvestigationDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'hazard_id') String? hazardId,
    @JsonKey(name: 'incident_id') String? incidentId,
    String? method,
    @JsonKey(name: 'immediate_cause') String? immediateCause,
    @JsonKey(name: 'contributing_factors') String? contributingFactors,
    @JsonKey(name: 'root_cause') String? rootCause,
    String? recommendations,
    Map<String, dynamic>? analysis,
    @JsonKey(name: 'investigator_id') required String investigatorId,
    @Default('open') String status,
    @JsonKey(name: 'opened_at') String? openedAt,
    @JsonKey(name: 'completed_at') String? completedAt,
    @Default(0) int version,
  }) = _InvestigationDto;

  factory InvestigationDto.fromJson(Map<String, dynamic> json) => _$InvestigationDtoFromJson(json);

  Investigation toEntity() => Investigation(
        id: id,
        companyId: companyId,
        siteId: siteId,
        hazardId: hazardId,
        incidentId: incidentId,
        method: InvestigationMethod.fromDb(method),
        immediateCause: immediateCause,
        contributingFactors: contributingFactors,
        rootCause: rootCause,
        recommendations: recommendations,
        analysis: InvestigationAnalysis.fromJson(analysis),
        investigatorId: investigatorId,
        status: InvestigationStatus.fromDb(status),
        openedAt: openedAt != null ? DateTime.parse(openedAt!) : DateTime.now(),
        completedAt: completedAt != null ? DateTime.tryParse(completedAt!) : null,
        version: version,
      );
}
