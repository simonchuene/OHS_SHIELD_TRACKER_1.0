// path: lib/features/inspections/domain/inspection_scoring.dart
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';

/// Pure scoring: percentage of PASS among answered pass/fail items (N/A excluded).
/// Returns null when there are no scorable items.
abstract final class InspectionScoring {
  static double? scorePercent(List<InspectionItem> items) {
    final scorable = items.where((i) => i.result == InspectionItemResult.pass || i.result == InspectionItemResult.fail).toList();
    if (scorable.isEmpty) return null;
    final passed = scorable.where((i) => i.result == InspectionItemResult.pass).length;
    return double.parse((passed / scorable.length * 100).toStringAsFixed(1));
  }

  /// All items must be answered (pass/fail/na) before an inspection can submit.
  static bool allAnswered(List<InspectionItem> items) => items.isNotEmpty && items.every((i) => i.isAnswered);
}
