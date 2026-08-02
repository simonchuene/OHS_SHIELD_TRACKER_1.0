// path: lib/features/inspections/application/inspection_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/inspection_scoring.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/repositories/inspection_repository.dart';

class InspectionUseCases {
  const InspectionUseCases(this._repo);
  final InspectionRepository _repo;

  Future<Result<List<Inspection>>> list() => _repo.list();
  Future<Result<Inspection>> get(String id) => _repo.get(id);

  Future<Result<Inspection>> create({
    required InspectionType type,
    required String companyId,
    required String inspectorId,
    String? siteId,
    String? departmentId,
    DateTime? scheduledDate,
  }) =>
      _repo.create(type: type, companyId: companyId, inspectorId: inspectorId, siteId: siteId, departmentId: departmentId, scheduledDate: scheduledDate);

  Future<Result<void>> setItemResult({
    required String itemId,
    required InspectionItemResult result,
    String? notes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) =>
      _repo.setItemResult(itemId: itemId, result: result, notes: notes, baseVersion: baseVersion, companyId: companyId, userId: userId);

  Future<Result<Inspection>> submit(Inspection inspection) {
    if (!InspectionScoring.allAnswered(inspection.items)) {
      return Future.value(const Err(ValidationFailure('Answer every checklist item before submitting.')));
    }
    return _repo.submit(inspection);
  }
}
