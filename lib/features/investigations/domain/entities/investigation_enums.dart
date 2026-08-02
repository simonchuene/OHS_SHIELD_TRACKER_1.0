// path: lib/features/investigations/domain/entities/investigation_enums.dart
/// Investigation methods (Master Prompt): 5 Whys · Fishbone. `dbValue` matches
/// the `investigation_method` enum.
enum InvestigationMethod {
  fiveWhys('five_whys', '5 Whys'),
  fishbone('fishbone', 'Fishbone');

  const InvestigationMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static InvestigationMethod? fromDb(String? v) => switch (v) {
        'five_whys' => InvestigationMethod.fiveWhys,
        'fishbone' => InvestigationMethod.fishbone,
        _ => null,
      };
}

/// Investigation lifecycle (STATUS GOVERNANCE): Open → In Progress →
/// Pending Review → Completed. `dbValue` matches `investigation_status`.
enum InvestigationStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In Progress'),
  pendingReview('pending_review', 'Pending Review'),
  completed('completed', 'Completed');

  const InvestigationStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static InvestigationStatus fromDb(String v) =>
      InvestigationStatus.values.firstWhere((e) => e.dbValue == v, orElse: () => InvestigationStatus.open);

  bool get isCompleted => this == InvestigationStatus.completed;
  int get step => InvestigationStatus.values.indexOf(this);
}
