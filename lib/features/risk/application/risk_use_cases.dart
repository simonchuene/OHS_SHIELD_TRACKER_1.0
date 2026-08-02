// path: lib/features/risk/application/risk_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/risk/domain/entities/risk_assessment.dart';
import 'package:ohs_shield_tracker/features/risk/domain/repositories/risk_assessment_repository.dart';
import 'package:ohs_shield_tracker/features/risk/domain/risk_calculator.dart';

class RiskUseCases {
  const RiskUseCases(this._repo);
  final RiskAssessmentRepository _repo;

  Future<Result<List<RiskAssessment>>> listForHazard(String hazardId) => _repo.listForHazard(hazardId);
  Future<Result<RiskAssessment?>> latestForHazard(String hazardId) => _repo.latestForHazard(hazardId);

  Future<Result<RiskAssessment>> save(SaveRiskParams p, {required String companyId, required String assessorId}) {
    if (!RiskCalculator.isValidFactor(p.likelihood) || !RiskCalculator.isValidFactor(p.severity)) {
      return Future.value(const Err(ValidationFailure('Likelihood and Severity must each be 1–5.')));
    }
    final residualPartial = (p.residualLikelihood == null) != (p.residualSeverity == null);
    if (residualPartial) {
      return Future.value(const Err(ValidationFailure('Provide both residual Likelihood and Severity, or neither.')));
    }
    if (p.residualLikelihood != null &&
        (!RiskCalculator.isValidFactor(p.residualLikelihood!) || !RiskCalculator.isValidFactor(p.residualSeverity!))) {
      return Future.value(const Err(ValidationFailure('Residual Likelihood and Severity must each be 1–5.')));
    }
    return _repo.saveAssessment(p, companyId: companyId, assessorId: assessorId);
  }
}
