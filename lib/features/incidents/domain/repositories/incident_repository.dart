// path: lib/features/incidents/domain/repositories/incident_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_filter.dart';

/// Incident data access + linkage engine. Reads merge server + cached (offline).
/// Create/update use the offline outbox; linkage/generation require connectivity.
abstract interface class IncidentRepository {
  Future<Result<List<Incident>>> listIncidents(IncidentFilter filter, {String? currentUserId});
  Future<Result<Incident>> getIncident(String id);

  Future<Result<Incident>> reportIncident(
    ReportIncidentParams params, {
    required String companyId,
    required String reporterId,
  });

  Future<Result<void>> updateIncident({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  });

  // --- Linkage engine (bidirectional Hazard↔Incident; Incident→Investigation/CAPA) ---
  Future<Result<void>> linkToHazard({required String incidentId, required String hazardId});

  /// Creates an investigation linked to the incident; returns its id.
  Future<Result<String>> generateInvestigation({
    required String incidentId,
    required String companyId,
    required String investigatorId,
    String? siteId,
  });

  /// Creates a CAPA linked to the incident; returns its id.
  Future<Result<String>> generateCapa({
    required String incidentId,
    required String companyId,
    required String description,
    required String priority,
    String? siteId,
    String? ownerId,
    DateTime? dueDate,
  });
}
