// path: lib/features/risk/domain/entities/risk_assessment.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/risk/domain/risk_calculator.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

part 'risk_assessment.freezed.dart';

/// A risk assessment of a hazard. `score`/`band` are computed (server: generated
/// columns; client: [RiskCalculator]) — never user-entered.
@freezed
class RiskAssessment with _$RiskAssessment {
  const RiskAssessment._();

  const factory RiskAssessment({
    required String id,
    required String companyId,
    required String hazardId,
    required int likelihood,
    required int severity,
    String? currentControls,
    String? requiredControls,
    int? residualLikelihood,
    int? residualSeverity,
    required String assessorId,
    DateTime? reviewDate,
    required DateTime assessedAt,
    @Default(0) int version,
  }) = _RiskAssessment;

  int get score => RiskCalculator.score(likelihood, severity);
  RiskBand get band => RiskCalculator.band(score);
  int? get residualScore =>
      (residualLikelihood != null && residualSeverity != null) ? residualLikelihood! * residualSeverity! : null;
  RiskBand? get residualBand => RiskCalculator.residualBand(residualLikelihood, residualSeverity);
}
