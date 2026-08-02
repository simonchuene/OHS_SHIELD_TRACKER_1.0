// path: lib/features/risk/data/risk_assessment_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/risk/domain/entities/risk_assessment.dart';

part 'risk_assessment_dto.freezed.dart';
part 'risk_assessment_dto.g.dart';

/// PostgREST / cache row for `risk_assessments`. Note: `risk_score` and
/// `risk_band` are GENERATED columns — they are read here but never sent on
/// insert (see [toInsert]).
@freezed
class RiskAssessmentDto with _$RiskAssessmentDto {
  const RiskAssessmentDto._();

  const factory RiskAssessmentDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'hazard_id') required String hazardId,
    required int likelihood,
    required int severity,
    @JsonKey(name: 'current_controls') String? currentControls,
    @JsonKey(name: 'required_controls') String? requiredControls,
    @JsonKey(name: 'residual_likelihood') int? residualLikelihood,
    @JsonKey(name: 'residual_severity') int? residualSeverity,
    @JsonKey(name: 'assessor_id') required String assessorId,
    @JsonKey(name: 'review_date') String? reviewDate,
    @JsonKey(name: 'assessed_at') String? assessedAt,
    @Default(0) int version,
  }) = _RiskAssessmentDto;

  factory RiskAssessmentDto.fromJson(Map<String, dynamic> json) => _$RiskAssessmentDtoFromJson(json);

  RiskAssessment toEntity() => RiskAssessment(
        id: id,
        companyId: companyId,
        hazardId: hazardId,
        likelihood: likelihood,
        severity: severity,
        currentControls: currentControls,
        requiredControls: requiredControls,
        residualLikelihood: residualLikelihood,
        residualSeverity: residualSeverity,
        assessorId: assessorId,
        reviewDate: reviewDate != null ? DateTime.tryParse(reviewDate!) : null,
        assessedAt: assessedAt != null ? DateTime.parse(assessedAt!) : DateTime.now(),
        version: version,
      );
}
