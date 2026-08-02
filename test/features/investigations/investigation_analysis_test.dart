// path: test/features/investigations/investigation_analysis_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_analysis.dart';

void main() {
  test('empty() seeds all 6M fishbone categories', () {
    final a = InvestigationAnalysis.empty();
    expect(a.fishbone.keys, containsAll(InvestigationAnalysis.fishboneCategories));
    expect(a.fiveWhys, isEmpty);
  });

  test('round-trips 5 whys + fishbone through JSON', () {
    final a = InvestigationAnalysis(
      fiveWhys: ['Machine stopped', 'Fuse blew', 'Overload'],
      fishbone: {'People': ['Untrained'], 'Equipment': ['No guard', 'Worn belt']},
    );
    final back = InvestigationAnalysis.fromJson(a.toJson());
    expect(back.fiveWhys, a.fiveWhys);
    expect(back.fishbone['Equipment'], ['No guard', 'Worn belt']);
    expect(back.fishbone['People'], ['Untrained']);
  });

  test('fromJson(null) is empty with categories', () {
    final a = InvestigationAnalysis.fromJson(null);
    expect(a.fiveWhys, isEmpty);
    expect(a.fishbone.keys, isNotEmpty);
  });
}
