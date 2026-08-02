// path: lib/features/capa/domain/entities/corrective_action.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';

part 'corrective_action.freezed.dart';

/// A corrective/preventive action. Originates from exactly one of Hazard,
/// Incident, Investigation, or a failed Inspection item (DB CHECK).
@freezed
class CorrectiveAction with _$CorrectiveAction {
  const CorrectiveAction._();

  const factory CorrectiveAction({
    required String id,
    required String companyId,
    String? siteId,
    String? actionCode,
    required String description,
    @Default(CapaPriority.medium) CapaPriority priority,
    String? ownerId,
    DateTime? dueDate,
    @Default(CapaStatus.created) CapaStatus status,
    String? hazardId,
    String? incidentId,
    String? investigationId,
    String? inspectionItemId,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? verificationNotes,
    DateTime? closedAt,
    @Default(0) int version,
  }) = _CorrectiveAction;

  bool get isClosed => status.isClosed;
  bool get hasOwner => ownerId != null;
  bool get isOverdue => dueDate != null && !isClosed && dueDate!.isBefore(DateTime.now());

  CapaSource get source {
    if (hazardId != null) return CapaSource.hazard;
    if (incidentId != null) return CapaSource.incident;
    if (investigationId != null) return CapaSource.investigation;
    if (inspectionItemId != null) return CapaSource.inspection;
    return CapaSource.unknown;
  }
}
