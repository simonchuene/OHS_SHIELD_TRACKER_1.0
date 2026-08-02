// path: lib/features/capa/application/capa_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/capa/domain/repositories/capa_repository.dart';

class CapaUseCases {
  const CapaUseCases(this._repo);
  final CapaRepository _repo;

  Future<Result<List<CorrectiveAction>>> list(CapaFilter f, {String? uid}) => _repo.list(f, currentUserId: uid);
  Future<Result<CorrectiveAction>> get(String id) => _repo.get(id);

  Future<Result<CorrectiveAction>> create({
    required String companyId,
    required String description,
    required CapaPriority priority,
    required CapaSourceRef source,
    String? siteId,
    String? ownerId,
    DateTime? dueDate,
    required String userId,
  }) {
    if (description.trim().isEmpty) {
      return Future.value(const Err(ValidationFailure('Description is required.')));
    }
    return _repo.create(
      companyId: companyId, description: description.trim(), priority: priority, source: source,
      siteId: siteId, ownerId: ownerId, dueDate: dueDate, userId: userId,
    );
  }

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) =>
      _repo.update(id: id, changes: changes, baseVersion: baseVersion, companyId: companyId, userId: userId);
}
