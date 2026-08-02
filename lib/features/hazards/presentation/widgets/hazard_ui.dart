// path: lib/features/hazards/presentation/widgets/hazard_ui.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_category.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

/// Category → icon (duotone treatment applies the colour separately).
IconData hazardCategoryIcon(HazardCategory c) => switch (c) {
      HazardCategory.physical => Icons.construction_rounded,
      HazardCategory.chemical => Icons.science_outlined,
      HazardCategory.biological => Icons.coronavirus_outlined,
      HazardCategory.ergonomic => Icons.accessibility_new_rounded,
      HazardCategory.psychosocial => Icons.psychology_outlined,
      HazardCategory.noise => Icons.volume_up_outlined,
      HazardCategory.radiation => Icons.warning_amber_rounded,
      HazardCategory.environmental => Icons.eco_outlined,
    };

/// Risk band → locked semantic colour (Critical uses full-intensity red).
Color hazardRiskColor(RiskBand? band) => switch (band) {
      RiskBand.low => AppColors.primaryGreen,
      RiskBand.medium => AppColors.warningAmber,
      RiskBand.high => AppColors.criticalRed,
      RiskBand.critical => AppColors.criticalRed,
      null => AppColors.infoBlue,
    };

/// Fully-rounded status pill (Item 2). Uses the risk colour when a risk band is
/// set, else a neutral tint keyed to the workflow stage.
class HazardStatusPill extends StatelessWidget {
  const HazardStatusPill({required this.status, this.risk, super.key});
  final HazardStatus status;
  final RiskBand? risk;

  @override
  Widget build(BuildContext context) {
    final color = status.isClosed ? AppColors.primaryGreen : hazardRiskColor(risk);
    final label = risk != null && !status.isClosed ? risk!.label : status.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],),
    );
  }
}
