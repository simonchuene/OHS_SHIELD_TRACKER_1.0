// path: lib/features/hazards/domain/entities/hazard_status.dart
/// Locked hazard lifecycle (Master Prompt STATUS GOVERNANCE):
/// Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed.
/// The transition state machine + guards are implemented in Prompt 8; this enum
/// is the shared vocabulary. `dbValue` matches the `hazard_status` Postgres enum.
enum HazardStatus {
  draft('draft', 'Draft'),
  submitted('submitted', 'Submitted'),
  assessment('assessment', 'Assessment'),
  investigation('investigation', 'Investigation'),
  capa('capa', 'CAPA'),
  verification('verification', 'Verification'),
  closed('closed', 'Closed');

  const HazardStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static HazardStatus fromDb(String v) =>
      HazardStatus.values.firstWhere((e) => e.dbValue == v, orElse: () => HazardStatus.draft);

  bool get isClosed => this == HazardStatus.closed;

  /// Ordered position for the detail-screen status stepper.
  int get step => HazardStatus.values.indexOf(this);
}
