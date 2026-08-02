// path: lib/features/inspections/domain/entities/inspection.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';

part 'inspection.freezed.dart';

@freezed
class InspectionItem with _$InspectionItem {
  const InspectionItem._();
  const factory InspectionItem({
    required String id,
    required String companyId,
    required String inspectionId,
    @Default(0) int position,
    required String prompt,
    InspectionItemResult? result,
    String? notes,
    String? generatedHazardId,
    String? generatedCapaId,
    @Default(0) int version,
  }) = _InspectionItem;

  bool get isFail => result == InspectionItemResult.fail;
  bool get isAnswered => result != null;
  bool get generated => generatedHazardId != null && generatedCapaId != null;
}

@freezed
class Inspection with _$Inspection {
  const Inspection._();
  const factory Inspection({
    required String id,
    required String companyId,
    String? siteId,
    String? departmentId,
    String? reference,
    required InspectionType type,
    required String inspectorId,
    @Default(InspectionStatus.draft) InspectionStatus status,
    DateTime? scheduledDate,
    DateTime? conductedAt,
    double? score,
    @Default(<InspectionItem>[]) List<InspectionItem> items,
    @Default(0) int version,
  }) = _Inspection;

  bool get isSubmitted => status.isSubmitted;
  int get failCount => items.where((i) => i.isFail).length;
  int get answeredCount => items.where((i) => i.isAnswered).length;
}
