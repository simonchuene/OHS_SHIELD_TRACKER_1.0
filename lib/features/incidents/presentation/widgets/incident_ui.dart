// path: lib/features/incidents/presentation/widgets/incident_ui.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';

/// Severity → locked colour token (Minor→Green · Moderate→Amber · Serious→Red ·
/// Critical→Red full intensity). Critical uses a deeper red for emphasis.
Color incidentSeverityColor(IncidentSeverity s) => switch (s) {
      IncidentSeverity.minor => AppColors.primaryGreen,
      IncidentSeverity.moderate => AppColors.warningAmber,
      IncidentSeverity.serious => AppColors.criticalRed,
      IncidentSeverity.critical => const Color(0xFF8E1616), // full-intensity red
    };

IconData incidentTypeIcon(IncidentType t) => switch (t) {
      IncidentType.nearMiss => Icons.warning_amber_rounded,
      IncidentType.firstAid => Icons.healing_outlined,
      IncidentType.medicalTreatment => Icons.local_hospital_outlined,
      IncidentType.lostTimeInjury => Icons.personal_injury_outlined,
      IncidentType.propertyDamage => Icons.broken_image_outlined,
      IncidentType.environmentalIncident => Icons.eco_outlined,
    };

class SeverityPill extends StatelessWidget {
  const SeverityPill({required this.severity, super.key});
  final IncidentSeverity severity;
  @override
  Widget build(BuildContext context) {
    final color = incidentSeverityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(severity.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],),
    );
  }
}
