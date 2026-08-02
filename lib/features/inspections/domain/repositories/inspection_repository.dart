// path: lib/features/inspections/domain/repositories/inspection_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';

abstract interface class InspectionRepository {
  Future<Result<List<Inspection>>> list();
  Future<Result<Inspection>> get(String id);

  /// Create an inspection pre-seeded with the template checklist for [type].
  Future<Result<Inspection>> create({
    required InspectionType type,
    required String companyId,
    required String inspectorId,
    String? siteId,
    String? departmentId,
    DateTime? scheduledDate,
  });

  Future<Result<void>> setItemResult({
    required String itemId,
    required InspectionItemResult result,
    String? notes,
    required int baseVersion,
    required String companyId,
    required String userId,
  });

  /// Finalise: for each failed item auto-create Hazard + CAPA (Edge Function),
  /// then set status = submitted with the computed score. Requires connectivity.
  Future<Result<Inspection>> submit(Inspection inspection);
}
