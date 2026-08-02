// path: test/features/incidents/incident_dto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/incidents/data/incident_dto.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';

void main() {
  test('maps row + POPIA-minimal witnesses to entity', () {
    final i = IncidentDto.fromJson({
      'id': 'i1', 'company_id': 'c1',
      'incident_type': 'lost_time_injury', 'severity': 'serious', 'status': 'reported',
      'occurred_at': '2026-07-31T14:00:00Z', 'reporter_id': 'u1',
      'witnesses': [
        {'name': 'A. Ndlovu', 'contact': '0800'},
        {'name': 'B. Peters'},
      ],
      'source_hazard_id': 'h9',
    }).toEntity();

    expect(i.type, IncidentType.lostTimeInjury);
    expect(i.severity, IncidentSeverity.serious);
    expect(i.status, IncidentStatus.reported);
    expect(i.witnesses.length, 2);
    expect(i.witnesses.first.name, 'A. Ndlovu');
    expect(i.witnesses[1].contact, isNull);
    expect(i.isLinkedToHazard, isTrue);
  });

  test('empty witnesses default', () {
    final i = IncidentDto.fromJson({
      'id': 'i2', 'company_id': 'c1', 'incident_type': 'near_miss', 'severity': 'minor',
      'status': 'reported', 'occurred_at': '2026-07-31T14:00:00Z', 'reporter_id': 'u1',
    }).toEntity();
    expect(i.witnesses, isEmpty);
    expect(i.isLinkedToHazard, isFalse);
  });
}
