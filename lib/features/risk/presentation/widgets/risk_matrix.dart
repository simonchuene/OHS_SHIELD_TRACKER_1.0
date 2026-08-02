// path: lib/features/risk/presentation/widgets/risk_matrix.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/widgets/hazard_ui.dart' show hazardRiskColor;
import 'package:ohs_shield_tracker/features/risk/domain/risk_calculator.dart';

/// 5×5 Likelihood × Severity matrix, each cell coloured by its band (locked
/// tokens). The current (likelihood, severity) cell is outlined. Tapping a cell
/// sets both factors.
class RiskMatrix extends StatelessWidget {
  const RiskMatrix({
    required this.likelihood,
    required this.severity,
    required this.onSelect,
    super.key,
  });

  final int likelihood;
  final int severity;
  final void Function(int likelihood, int severity) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Severity →', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        // Rows = likelihood 5..1 (top to bottom), cols = severity 1..5.
        for (var l = 5; l >= 1; l--)
          Row(children: [
            SizedBox(width: 16, child: Text('$l', style: Theme.of(context).textTheme.labelSmall)),
            for (var s = 1; s <= 5; s++) _cell(l, s),
          ],),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Row(children: [for (var s = 1; s <= 5; s++) SizedBox(width: 40, child: Center(child: Text('$s', style: Theme.of(context).textTheme.labelSmall)))]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Text('↑ Likelihood', style: Theme.of(context).textTheme.labelSmall),
        ),
      ],
    );
  }

  Widget _cell(int l, int s) {
    final score = RiskCalculator.score(l, s);
    final color = hazardRiskColor(RiskCalculator.band(score));
    final selected = l == likelihood && s == severity;
    return GestureDetector(
      onTap: () => onSelect(l, s),
      child: Container(
        width: 40,
        height: 36,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.9 : 0.35),
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: Colors.black87, width: 2) : null,
        ),
        child: Center(
          child: Text('$score',
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black87,
              ),),
        ),
      ),
    );
  }
}
