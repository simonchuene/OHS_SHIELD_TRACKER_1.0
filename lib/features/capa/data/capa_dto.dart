// path: lib/features/capa/data/capa_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';

part 'capa_dto.freezed.dart';
part 'capa_dto.g.dart';

@freezed
class CapaDto with _$CapaDto {
  const CapaDto._();

  const factory CapaDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'action_code') String? actionCode,
    required String description,
    @Default('medium') String priority,
    @JsonKey(name: 'owner_id') String? ownerId,
    @JsonKey(name: 'due_date') String? dueDate,
    @Default('created') String status,
    @JsonKey(name: 'hazard_id') String? hazardId,
    @JsonKey(name: 'incident_id') String? incidentId,
    @JsonKey(name: 'investigation_id') String? investigationId,
    @JsonKey(name: 'inspection_item_id') String? inspectionItemId,
    @JsonKey(name: 'verified_by') String? verifiedBy,
    @JsonKey(name: 'verified_at') String? verifiedAt,
    @JsonKey(name: 'completion_notes') String? completionNotes,
    @JsonKey(name: 'verification_notes') String? verificationNotes,
    @JsonKey(name: 'closed_at') String? closedAt,
    @Default(0) int version,
  }) = _CapaDto;

  factory CapaDto.fromJson(Map<String, dynamic> json) => _$CapaDtoFromJson(json);

  CorrectiveAction toEntity() => CorrectiveAction(
        id: id,
        companyId: companyId,
        siteId: siteId,
        actionCode: actionCode,
        description: description,
        priority: CapaPriority.fromDb(priority),
        ownerId: ownerId,
        dueDate: dueDate != null ? DateTime.tryParse(dueDate!) : null,
        status: CapaStatus.fromDb(status),
        hazardId: hazardId,
        incidentId: incidentId,
        investigationId: investigationId,
        inspectionItemId: inspectionItemId,
        verifiedBy: verifiedBy,
        verifiedAt: verifiedAt != null ? DateTime.tryParse(verifiedAt!) : null,
        completionNotes: completionNotes,
        verificationNotes: verificationNotes,
        closedAt: closedAt != null ? DateTime.tryParse(closedAt!) : null,
        version: version,
      );
}
