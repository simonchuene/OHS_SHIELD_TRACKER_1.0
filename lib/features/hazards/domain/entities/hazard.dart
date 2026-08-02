// path: lib/features/hazards/domain/entities/hazard.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

part 'hazard.freezed.dart';

/// A workplace hazard. Immutable domain entity (JSON handled by HazardDto).
@freezed
class Hazard with _$Hazard {
  const Hazard._();

  const factory Hazard({
    required String id,
    required String companyId,
    String? siteId,
    String? departmentId,
    String? reference,
    required String title,
    String? description,
    required HazardCategory category,
    @Default(HazardStatus.draft) HazardStatus status,
    RiskBand? riskLevel,
    required String reporterId,
    double? latitude,
    double? longitude,
    String? locationText,
    String? sourceIncidentId,
    required DateTime reportedAt,
    @Default(0) int version,
  }) = _Hazard;

  bool get hasLocation => latitude != null && longitude != null;
  bool get isClosed => status.isClosed;
}
