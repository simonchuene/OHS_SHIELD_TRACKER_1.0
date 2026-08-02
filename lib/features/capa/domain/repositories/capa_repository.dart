// path: lib/features/capa/domain/repositories/capa_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';

class CapaFilter {
  const CapaFilter({this.status, this.priority, this.query, this.mineOnly = false});
  final CapaStatus? status;
  final CapaPriority? priority;
  final String? query;
  final bool mineOnly;

  CapaFilter copyWith({CapaStatus? status, CapaPriority? priority, String? query, bool? mineOnly, bool clearStatus = false}) =>
      CapaFilter(
        status: clearStatus ? null : (status ?? this.status),
        priority: priority ?? this.priority,
        query: query ?? this.query,
        mineOnly: mineOnly ?? this.mineOnly,
      );
}

/// Which source a new CAPA links to (exactly one).
class CapaSourceRef {
  const CapaSourceRef({this.hazardId, this.incidentId, this.investigationId, this.inspectionItemId});
  final String? hazardId;
  final String? incidentId;
  final String? investigationId;
  final String? inspectionItemId;

  bool get isValid =>
      [hazardId, incidentId, investigationId, inspectionItemId].where((e) => e != null).length == 1;
}

abstract interface class CapaRepository {
  Future<Result<List<CorrectiveAction>>> list(CapaFilter filter, {String? currentUserId});
  Future<Result<CorrectiveAction>> get(String id);

  Future<Result<CorrectiveAction>> create({
    required String companyId,
    required String description,
    required CapaPriority priority,
    required CapaSourceRef source,
    String? siteId,
    String? ownerId,
    DateTime? dueDate,
    required String userId,
  });

  Future<Result<void>> update({
    required String id,
    required Map<String, dynamic> changes,
    required int baseVersion,
    required String companyId,
    required String userId,
  });
}
