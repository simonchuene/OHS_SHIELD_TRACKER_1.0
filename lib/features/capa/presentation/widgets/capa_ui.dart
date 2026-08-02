// path: lib/features/capa/presentation/widgets/capa_ui.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';

Color capaPriorityColor(CapaPriority p) => switch (p) {
      CapaPriority.critical => const Color(0xFF8E1616),
      CapaPriority.high => AppColors.criticalRed,
      CapaPriority.medium => AppColors.warningAmber,
      CapaPriority.low => AppColors.primaryGreen,
    };

String capaSourceLabel(CapaSource s) => switch (s) {
      CapaSource.hazard => 'From hazard',
      CapaSource.incident => 'From incident',
      CapaSource.investigation => 'From investigation',
      CapaSource.inspection => 'From inspection',
      CapaSource.unknown => 'Standalone',
    };

class PriorityPill extends StatelessWidget {
  const PriorityPill({required this.priority, super.key});
  final CapaPriority priority;
  @override
  Widget build(BuildContext context) {
    final color = capaPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(priority.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],),
    );
  }
}
