// path: lib/features/incidents/domain/entities/incident_enums.dart
/// Locked incident domain values (Master Prompt INCIDENT MANAGEMENT). `dbValue`
/// matches the Postgres enums.
library;


enum IncidentType {
  nearMiss('near_miss', 'Near Miss'),
  firstAid('first_aid', 'First Aid'),
  medicalTreatment('medical_treatment', 'Medical Treatment'),
  lostTimeInjury('lost_time_injury', 'Lost Time Injury'),
  propertyDamage('property_damage', 'Property Damage'),
  environmentalIncident('environmental_incident', 'Environmental Incident');

  const IncidentType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static IncidentType fromDb(String v) =>
      IncidentType.values.firstWhere((e) => e.dbValue == v, orElse: () => IncidentType.nearMiss);
}

/// Locked severity scale (Minor→Green · Moderate→Amber · Serious→Red ·
/// Critical→Red full intensity). Ordered enum; drives card colour, dashboard
/// placement, and notification priority. Colour mapping lives in the UI layer.
enum IncidentSeverity {
  minor('minor', 'Minor'),
  moderate('moderate', 'Moderate'),
  serious('serious', 'Serious'),
  critical('critical', 'Critical');

  const IncidentSeverity(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static IncidentSeverity fromDb(String v) =>
      IncidentSeverity.values.firstWhere((e) => e.dbValue == v, orElse: () => IncidentSeverity.minor);
}

enum IncidentStatus {
  reported('reported', 'Reported'),
  investigated('investigated', 'Investigated'),
  capa('capa', 'CAPA'),
  verified('verified', 'Verified'),
  closed('closed', 'Closed');

  const IncidentStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static IncidentStatus fromDb(String v) =>
      IncidentStatus.values.firstWhere((e) => e.dbValue == v, orElse: () => IncidentStatus.reported);

  bool get isClosed => this == IncidentStatus.closed;
  int get step => IncidentStatus.values.indexOf(this);
}
