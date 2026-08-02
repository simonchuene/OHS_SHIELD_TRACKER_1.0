// path: lib/features/audit/domain/audit_filter.dart
/// Audit Log Viewer filters (by user, action, entity type, date range).
class AuditFilter {
  const AuditFilter({this.actorId, this.action, this.entityType, this.from, this.to});
  final String? actorId;
  final String? action; // free-text (ilike on action)
  final String? entityType;
  final DateTime? from;
  final DateTime? to;

  /// Entity types that appear in audit_logs (for the filter dropdown).
  static const entityTypes = [
    'hazard', 'incident', 'risk_assessment', 'investigation',
    'corrective_action', 'inspection', 'inspection_item', 'user',
  ];

  AuditFilter copyWith({
    String? actorId, String? action, String? entityType, DateTime? from, DateTime? to,
    bool clearActor = false, bool clearEntity = false, bool clearFrom = false, bool clearTo = false,
  }) =>
      AuditFilter(
        actorId: clearActor ? null : (actorId ?? this.actorId),
        action: action ?? this.action,
        entityType: clearEntity ? null : (entityType ?? this.entityType),
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
      );
}
