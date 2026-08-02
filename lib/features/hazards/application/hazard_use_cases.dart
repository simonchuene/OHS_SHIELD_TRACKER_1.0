// path: lib/features/hazards/application/hazard_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/repositories/hazard_repository.dart';

/// Hazard application layer. Validation lives here; lifecycle transitions are
/// added by the workflow engine (Prompt 8).
class HazardUseCases {
  const HazardUseCases(this._repo);
  final HazardRepository _repo;

  Future<Result<List<Hazard>>> list(HazardFilter filter, {String? uid}) =>
      _repo.listHazards(filter, currentUserId: uid);

  Future<Result<Hazard>> get(String id) => _repo.getHazard(id);

  Future<Result<Hazard>> report(
    ReportHazardParams params, {
    required String companyId,
    required String reporterId,
  }) {
    final title = params.title.trim();
    if (title.isEmpty) {
      return Future.value(const Err(ValidationFailure('Title is required.', fieldErrors: {'title': 'Title is required.'})));
    }
    if (title.length > 120) {
      return Future.value(const Err(ValidationFailure('Title must be 120 characters or fewer.')));
    }
    return _repo.reportHazard(params, companyId: companyId, reporterId: reporterId);
  }

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) =>
      _repo.updateHazard(id: id, changes: changes, baseVersion: baseVersion, companyId: companyId, userId: userId);
}
