// path: lib/features/inspections/data/inspection_dtos.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';

part 'inspection_dtos.freezed.dart';
part 'inspection_dtos.g.dart';

@freezed
class InspectionItemDto with _$InspectionItemDto {
  const InspectionItemDto._();
  const factory InspectionItemDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'inspection_id') required String inspectionId,
    @Default(0) int position,
    required String prompt,
    String? result,
    String? notes,
    @JsonKey(name: 'generated_hazard_id') String? generatedHazardId,
    @JsonKey(name: 'generated_capa_id') String? generatedCapaId,
    @Default(0) int version,
  }) = _InspectionItemDto;

  factory InspectionItemDto.fromJson(Map<String, dynamic> json) => _$InspectionItemDtoFromJson(json);

  InspectionItem toEntity() => InspectionItem(
        id: id,
        companyId: companyId,
        inspectionId: inspectionId,
        position: position,
        prompt: prompt,
        result: InspectionItemResult.fromDb(result),
        notes: notes,
        generatedHazardId: generatedHazardId,
        generatedCapaId: generatedCapaId,
        version: version,
      );
}

@freezed
class InspectionDto with _$InspectionDto {
  const InspectionDto._();
  const factory InspectionDto({
    required String id,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'department_id') String? departmentId,
    String? reference,
    @JsonKey(name: 'inspection_type') required String inspectionType,
    @JsonKey(name: 'inspector_id') required String inspectorId,
    @Default('draft') String status,
    @JsonKey(name: 'scheduled_date') String? scheduledDate,
    @JsonKey(name: 'conducted_at') String? conductedAt,
    num? score,
    @JsonKey(name: 'inspection_items') List<InspectionItemDto>? items,
    @Default(0) int version,
  }) = _InspectionDto;

  factory InspectionDto.fromJson(Map<String, dynamic> json) => _$InspectionDtoFromJson(json);

  Inspection toEntity({List<InspectionItem>? overrideItems}) => Inspection(
        id: id,
        companyId: companyId,
        siteId: siteId,
        departmentId: departmentId,
        reference: reference,
        type: InspectionType.fromDb(inspectionType),
        inspectorId: inspectorId,
        status: InspectionStatus.fromDb(status),
        scheduledDate: scheduledDate != null ? DateTime.tryParse(scheduledDate!) : null,
        conductedAt: conductedAt != null ? DateTime.tryParse(conductedAt!) : null,
        score: score?.toDouble(),
        // Copy before sorting. Both fallbacks can hand back an unmodifiable
        // list — `const []` here, and `list()` passes `overrideItems: const []`
        // because the list query does not fetch items — so sorting in place
        // threw for every row and the caller's catch reported it as "server
        // unavailable". List.of also accepts the Iterable from map() directly.
        items: List<InspectionItem>.of(
          overrideItems ?? items?.map((e) => e.toEntity()) ?? const [],
        )..sort((a, b) => a.position.compareTo(b.position)),
        version: version,
      );
}
