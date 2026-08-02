// path: lib/features/incidents/application/incident_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_filter.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/repositories/incident_repository.dart';

class IncidentUseCases {
  const IncidentUseCases(this._repo);
  final IncidentRepository _repo;

  Future<Result<List<Incident>>> list(IncidentFilter f, {String? uid}) =>
      _repo.listIncidents(f, currentUserId: uid);
  Future<Result<Incident>> get(String id) => _repo.getIncident(id);

  Future<Result<Incident>> report(ReportIncidentParams p,
      {required String companyId, required String reporterId,}) {
    if (p.occurredAt.isAfter(DateTime.now())) {
      return Future.value(const Err(ValidationFailure('Occurred date/time cannot be in the future.')));
    }
    return _repo.reportIncident(p, companyId: companyId, reporterId: reporterId);
  }

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  }) =>
      _repo.updateIncident(id: id, changes: changes, baseVersion: baseVersion, companyId: companyId, userId: userId);

  Future<Result<void>> linkToHazard(String incidentId, String hazardId) =>
      _repo.linkToHazard(incidentId: incidentId, hazardId: hazardId);

  Future<Result<String>> generateInvestigation(String incidentId, String companyId, String investigatorId, {String? siteId}) =>
      _repo.generateInvestigation(incidentId: incidentId, companyId: companyId, investigatorId: investigatorId, siteId: siteId);

  Future<Result<String>> generateCapa(String incidentId, String companyId, String description, String priority, {String? siteId}) =>
      _repo.generateCapa(incidentId: incidentId, companyId: companyId, description: description, priority: priority, siteId: siteId);
}
