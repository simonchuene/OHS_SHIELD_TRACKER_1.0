// path: lib/services/sync/sync_models.dart
/// Per-record sync status surfaced in the UI (locked set — Master Prompt /
/// Prompt 3 §9.4). String values match `CachedRecords.syncStatus` and the
/// server `sync_status` enum.
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed;

  static SyncStatus fromName(String? v) =>
      SyncStatus.values.firstWhere((e) => e.name == v, orElse: () => SyncStatus.synced);
}

/// Mutation kind mirrored in `sync_queue.operation`.
enum SyncOperation { insert, update, delete }

/// Conflict-resolution strategy per entity (D4, two-tier).
enum ConflictStrategy {
  /// Last-write-wins by `updated_at`, with the overwrite captured in the audit
  /// trail. Whole-row.
  lastWriteWins,

  /// Field-level merge: the offline editor's touched fields win; untouched
  /// fields keep the server value. Same-field conflict falls back to the
  /// client value (defined tie-break).
  fieldMerge,
}

/// Canonical entity types (match server `entity_type` / table names).
abstract final class SyncEntity {
  static const hazard = 'hazard';
  static const incident = 'incident';
  static const riskAssessment = 'risk_assessment';
  static const investigation = 'investigation';
  static const correctiveAction = 'corrective_action';
  static const inspection = 'inspection';
  static const inspectionItem = 'inspection_item';

  /// Maps each offline-writable entity to its resolution strategy (D4).
  static const Map<String, ConflictStrategy> strategyByEntity = {
    hazard: ConflictStrategy.lastWriteWins,
    incident: ConflictStrategy.lastWriteWins,
    riskAssessment: ConflictStrategy.lastWriteWins,
    investigation: ConflictStrategy.lastWriteWins,
    inspection: ConflictStrategy.lastWriteWins,
    correctiveAction: ConflictStrategy.fieldMerge,
    inspectionItem: ConflictStrategy.fieldMerge,
  };

  /// Server table name for a given entity type.
  static const Map<String, String> tableByEntity = {
    hazard: 'hazards',
    incident: 'incidents',
    riskAssessment: 'risk_assessments',
    investigation: 'investigations',
    correctiveAction: 'corrective_actions',
    inspection: 'inspections',
    inspectionItem: 'inspection_items',
  };

  static ConflictStrategy strategyFor(String entityType) =>
      strategyByEntity[entityType] ?? ConflictStrategy.lastWriteWins;

  static String tableFor(String entityType) =>
      tableByEntity[entityType] ??
      (throw ArgumentError('Unknown sync entity: $entityType'));
}
