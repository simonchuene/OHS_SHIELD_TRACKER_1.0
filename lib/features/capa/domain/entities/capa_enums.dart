// path: lib/features/capa/domain/entities/capa_enums.dart
/// CAPA status (STATUS GOVERNANCE): Created → Assigned → In Progress →
/// Verification → Closed. `dbValue` matches `capa_status`.
enum CapaStatus {
  created('created', 'Created'),
  assigned('assigned', 'Assigned'),
  inProgress('in_progress', 'In Progress'),
  verification('verification', 'Verification'),
  closed('closed', 'Closed');

  const CapaStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CapaStatus fromDb(String v) =>
      CapaStatus.values.firstWhere((e) => e.dbValue == v, orElse: () => CapaStatus.created);

  bool get isClosed => this == CapaStatus.closed;
  int get step => CapaStatus.values.indexOf(this);
}

/// CAPA priority (Master Prompt). `dbValue` matches `capa_priority`.
enum CapaPriority {
  critical('critical', 'Critical'),
  high('high', 'High'),
  medium('medium', 'Medium'),
  low('low', 'Low');

  const CapaPriority(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CapaPriority fromDb(String v) =>
      CapaPriority.values.firstWhere((e) => e.dbValue == v, orElse: () => CapaPriority.medium);
}

/// Which entity a CAPA originated from (exactly one — DB CHECK).
enum CapaSource { hazard, incident, investigation, inspection, unknown }
