// path: test/features/hazards/hazard_dto_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/hazards/data/hazard_dto.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

void main() {
  test('maps a server/cache row to a Hazard entity', () {
    final dto = HazardDto.fromJson({
      'id': 'h1',
      'company_id': 'c1',
      'site_id': 's1',
      'title': 'Exposed conveyor guard',
      'category': 'physical',
      'status': 'submitted',
      'risk_level': 'high',
      'reporter_id': 'u1',
      'reported_at': '2026-08-01T08:00:00Z',
      'version': 2,
    });
    final h = dto.toEntity();
    expect(h.category, HazardCategory.physical);
    expect(h.status, HazardStatus.submitted);
    expect(h.riskLevel, RiskBand.high);
    expect(h.version, 2);
    expect(h.hasLocation, isFalse);
  });

  test('unknown enum values fall back safely; missing risk = null', () {
    final h = HazardDto.fromJson({
      'id': 'h2', 'company_id': 'c1', 'title': 'x', 'category': 'physical',
      'status': 'draft', 'reporter_id': 'u1',
    }).toEntity();
    expect(h.riskLevel, isNull);
    expect(h.status, HazardStatus.draft);
  });
}
