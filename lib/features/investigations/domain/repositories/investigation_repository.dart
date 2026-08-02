// path: lib/features/investigations/domain/repositories/investigation_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';

abstract interface class InvestigationRepository {
  /// List investigations, optionally filtered to a hazard or an incident.
  Future<Result<List<Investigation>>> list({String? hazardId, String? incidentId});
  Future<Result<Investigation>> getInvestigation(String id);

  /// Create an investigation from exactly one origin (hazard or incident).
  Future<Result<Investigation>> create({
    required String companyId,
    required String investigatorId,
    String? hazardId,
    String? incidentId,
    String? siteId,
  });

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  });

  /// Create a CAPA linked to this investigation; returns its id.
  Future<Result<String>> generateCapa({
    required String investigationId,
    required String companyId,
    required String description,
    required String priority,
    String? siteId,
  });
}
