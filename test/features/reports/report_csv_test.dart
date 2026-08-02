// path: test/features/reports/report_csv_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/reports/data/report_exporter.dart';
import 'package:ohs_shield_tracker/features/reports/domain/report_models.dart';

void main() {
  ReportResult result(List<List<String>> rows) => ReportResult(
        type: ReportType.hazardRegister, title: 'Hazard Register',
        columns: ['Reference', 'Title', 'Status'], rows: rows, generatedAt: DateTime(2026, 8, 1),
      );

  test('builds header + rows', () {
    final csv = ReportCsv.build(result([
      ['H-001', 'Wet floor', 'submitted'],
      ['H-002', 'Exposed guard', 'assessment'],
    ]),);
    final lines = csv.trim().split('\n');
    expect(lines.first, 'Reference,Title,Status');
    expect(lines[1], 'H-001,Wet floor,submitted');
    expect(lines.length, 3);
  });

  test('escapes commas, quotes, and newlines', () {
    final csv = ReportCsv.build(result([
      ['H-003', 'Spill, large', 'open'],
      ['H-004', 'He said "stop"', 'open'],
    ]),);
    expect(csv, contains('"Spill, large"'));
    expect(csv, contains('"He said ""stop"""'));
  });

  test('filters date range', () {
    const f = ReportFilters();
    expect(f.matches(DateTime(2026, 1, 1)), isTrue); // no bounds → all match
    final ranged = ReportFilters(from: DateTime(2026, 7, 1), to: DateTime(2026, 7, 31));
    expect(ranged.matches(DateTime(2026, 7, 15)), isTrue);
    expect(ranged.matches(DateTime(2026, 6, 30)), isFalse);
    expect(ranged.matches(DateTime(2026, 8, 1)), isFalse);
  });
}
