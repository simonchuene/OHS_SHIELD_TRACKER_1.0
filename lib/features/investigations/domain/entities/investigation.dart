// path: lib/features/investigations/domain/entities/investigation.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';

part 'investigation.freezed.dart';

/// A root-cause investigation originating from a Hazard OR an Incident
/// (exactly one — enforced by the DB CHECK). Root cause + recommendations are
/// mandatory to reach Completed.
@freezed
class Investigation with _$Investigation {
  const Investigation._();

  const factory Investigation({
    required String id,
    required String companyId,
    String? siteId,
    String? hazardId,
    String? incidentId,
    InvestigationMethod? method,
    String? immediateCause,
    String? contributingFactors,
    String? rootCause,
    String? recommendations,
    required InvestigationAnalysis analysis,
    required String investigatorId,
    @Default(InvestigationStatus.open) InvestigationStatus status,
    required DateTime openedAt,
    DateTime? completedAt,
    @Default(0) int version,
  }) = _Investigation;

  bool get isCompleted => status.isCompleted;
  bool get hasRootCause => (rootCause?.trim().isNotEmpty ?? false);
  bool get hasRecommendations => (recommendations?.trim().isNotEmpty ?? false);
  bool get originatesFromIncident => incidentId != null;
}
