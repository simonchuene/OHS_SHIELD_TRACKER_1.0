// path: lib/features/investigations/application/investigation_use_cases.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/repositories/investigation_repository.dart';

class InvestigationUseCases {
  const InvestigationUseCases(this._repo);
  final InvestigationRepository _repo;

  Future<Result<List<Investigation>>> list({String? hazardId, String? incidentId}) =>
      _repo.list(hazardId: hazardId, incidentId: incidentId);
  Future<Result<Investigation>> get(String id) => _repo.getInvestigation(id);

  Future<Result<Investigation>> create({
    required String companyId,
    required String investigatorId,
    String? hazardId,
    String? incidentId,
    String? siteId,
  }) =>
      _repo.create(companyId: companyId, investigatorId: investigatorId, hazardId: hazardId, incidentId: incidentId, siteId: siteId);

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) =>
      _repo.update(id: id, changes: changes, baseVersion: baseVersion, companyId: companyId, userId: userId);

  Future<Result<String>> generateCapa(String investigationId, String companyId, String description, String priority, {String? siteId}) =>
      _repo.generateCapa(investigationId: investigationId, companyId: companyId, description: description, priority: priority, siteId: siteId);
}
