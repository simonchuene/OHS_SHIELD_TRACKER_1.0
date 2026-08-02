// path: lib/features/risk/domain/repositories/risk_assessment_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/risk/domain/entities/risk_assessment.dart';

/// Parameters for saving an assessment. Score/band are derived, not passed.
class SaveRiskParams {
  const SaveRiskParams({
    required this.hazardId,
    required this.likelihood,
    required this.severity,
    this.currentControls,
    this.requiredControls,
    this.residualLikelihood,
    this.residualSeverity,
    this.reviewDate,
  });

  final String hazardId;
  final int likelihood;
  final int severity;
  final String? currentControls;
  final String? requiredControls;
  final int? residualLikelihood;
  final int? residualSeverity;
  final DateTime? reviewDate;
}

abstract interface class RiskAssessmentRepository {
  Future<Result<List<RiskAssessment>>> listForHazard(String hazardId);
  Future<Result<RiskAssessment?>> latestForHazard(String hazardId);

  /// Offline-capable create (draft support). Returns the local record; the DB
  /// computes score/band and syncs `hazards.risk_level` on insert (trigger 0014).
  Future<Result<RiskAssessment>> saveAssessment(
    SaveRiskParams params, {
    required String companyId,
    required String assessorId,
  });
}
