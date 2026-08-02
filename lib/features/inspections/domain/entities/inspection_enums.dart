// path: lib/features/inspections/domain/entities/inspection_enums.dart
/// Inspection types (Master Prompt). `dbValue` matches `inspection_type`.
enum InspectionType {
  housekeeping('housekeeping', 'Housekeeping'),
  fireSafety('fire_safety', 'Fire Safety'),
  ppe('ppe', 'PPE'),
  vehicle('vehicle', 'Vehicle'),
  equipment('equipment', 'Equipment');

  const InspectionType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static InspectionType fromDb(String v) =>
      InspectionType.values.firstWhere((e) => e.dbValue == v, orElse: () => InspectionType.housekeeping);
}

/// Inspection lifecycle: Draft → In Progress → Submitted → Closed.
enum InspectionStatus {
  draft('draft', 'Draft'),
  inProgress('in_progress', 'In Progress'),
  submitted('submitted', 'Submitted'),
  closed('closed', 'Closed');

  const InspectionStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static InspectionStatus fromDb(String v) =>
      InspectionStatus.values.firstWhere((e) => e.dbValue == v, orElse: () => InspectionStatus.draft);

  bool get isSubmitted => this == InspectionStatus.submitted || this == InspectionStatus.closed;
}

/// Checklist item result. Only pass/fail count toward the score; n/a is excluded.
enum InspectionItemResult {
  pass('pass', 'Pass'),
  fail('fail', 'Fail'),
  na('na', 'N/A');

  const InspectionItemResult(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static InspectionItemResult? fromDb(String? v) => switch (v) {
        'pass' => InspectionItemResult.pass,
        'fail' => InspectionItemResult.fail,
        'na' => InspectionItemResult.na,
        _ => null,
      };
}
