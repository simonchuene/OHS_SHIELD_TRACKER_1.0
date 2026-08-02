// path: lib/features/hazards/domain/repositories/hazard_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';

/// Hazard data access. Reads merge server (PostgREST, RLS-scoped) with locally
/// cached pending rows so offline-created hazards are visible immediately.
/// Writes go through the offline outbox (Prompt 4B) and sync when online.
abstract interface class HazardRepository {
  Future<Result<List<Hazard>>> listHazards(HazardFilter filter, {String? currentUserId});
  Future<Result<Hazard>> getHazard(String id);

  /// Optimistic create — returns immediately with a `pending` local record.
  Future<Result<Hazard>> reportHazard(
    ReportHazardParams params, {
    required String companyId,
    required String reporterId,
  });

  /// Queue a field-level update (used by the workflow engine, Prompt 8).
  Future<Result<void>> updateHazard({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  });
}
