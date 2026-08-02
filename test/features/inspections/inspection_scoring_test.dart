// path: test/features/inspections/inspection_scoring_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/checklist_templates.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/inspection_scoring.dart';

void main() {
  InspectionItem item(InspectionItemResult? r) =>
      InspectionItem(id: 'i', companyId: 'c', inspectionId: 'x', prompt: 'p', result: r);

  test('score = % pass among pass/fail; N/A excluded', () {
    final items = [
      item(InspectionItemResult.pass),
      item(InspectionItemResult.pass),
      item(InspectionItemResult.fail),
      item(InspectionItemResult.na), // excluded
    ];
    // 2 pass of 3 scorable = 66.7
    expect(InspectionScoring.scorePercent(items), 66.7);
  });

  test('all N/A or empty → null score', () {
    expect(InspectionScoring.scorePercent([item(InspectionItemResult.na)]), isNull);
    expect(InspectionScoring.scorePercent([]), isNull);
  });

  test('allAnswered requires every item answered', () {
    expect(InspectionScoring.allAnswered([item(InspectionItemResult.pass), item(null)]), isFalse);
    expect(InspectionScoring.allAnswered([item(InspectionItemResult.pass), item(InspectionItemResult.fail)]), isTrue);
    expect(InspectionScoring.allAnswered([]), isFalse);
  });

  test('every inspection type has a seed checklist', () {
    for (final t in InspectionType.values) {
      expect(ChecklistTemplates.forType(t), isNotEmpty, reason: t.label);
    }
  });
}
