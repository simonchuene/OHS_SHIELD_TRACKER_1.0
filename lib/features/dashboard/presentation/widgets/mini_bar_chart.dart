// path: lib/features/dashboard/presentation/widgets/mini_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// A lightweight bar chart (no chart dependency) for the incident/hazard trend
/// and department risk ranking — consistent with the flat, restrained theme.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({required this.values, required this.labels, this.color = AppColors.infoBlue, this.height = 90, super.key});
  final List<int> values;
  final List<String> labels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = (values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b)).clamp(1, 1 << 30);
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(children: [
              Text('${values[i]}', style: Theme.of(context).textTheme.labelSmall, maxLines: 1),
              const SizedBox(height: 2),
              // The bar takes whatever is left after the two labels rather than
              // a hardcoded (height - 34). That constant assumed 14px per label
              // when labelSmall is 12pt on a ~16px line, overflowing by exactly
              // 4px — and it would have drifted again with any type-scale change
              // or a user's larger font setting.
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: (values[i] / maxV).clamp(0.0, 1.0),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(i < labels.length ? labels[i] : '', style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],),
          ),
      ],),
    );
  }
}

/// Horizontal ranking bars (department risk).
class RankingBars extends StatelessWidget {
  const RankingBars({required this.entries, this.color = AppColors.criticalRed, super.key});
  final List<(String, int)> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('No high-risk hazards.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondaryText));
    }
    final maxV = entries.map((e) => e.$2).reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 96, child: Text(e.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)),
            Expanded(
              child: Stack(children: [
                Container(height: 14, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7))),
                FractionallySizedBox(
                  widthFactor: e.$2 / maxV,
                  child: Container(height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7))),
                ),
              ],),
            ),
            const SizedBox(width: 8),
            Text('${e.$2}', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
          ],),
        ),
    ],);
  }
}
