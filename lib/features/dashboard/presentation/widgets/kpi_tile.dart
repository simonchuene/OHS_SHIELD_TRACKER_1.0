// path: lib/features/dashboard/presentation/widgets/kpi_tile.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/shared/widgets/duotone_icon_badge.dart';

/// Dashboard KPI tile (Master Prompt Item 7a): duotone icon badge → oversized
/// tabular numeral → secondary label → short semantic underline accent.
class KpiTile extends StatelessWidget {
  const KpiTile({required this.icon, required this.color, required this.value, required this.label, this.onTap, super.key});
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DuotoneIconBadge(icon: icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            Text(label, style: Theme.of(context).textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Container(width: 20, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          ],),
        ),
      ),
    );
  }
}
