// path: lib/features/inspections/domain/checklist_templates.dart
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';

/// Default checklist prompts per inspection type (the "checklist engine" seed).
/// A new inspection is created with these items; an inspector can still add/skip.
abstract final class ChecklistTemplates {
  static const Map<InspectionType, List<String>> byType = {
    InspectionType.housekeeping: [
      'Walkways and aisles are clear of obstructions',
      'Floors are free of spills and trip hazards',
      'Waste is stored and disposed of correctly',
      'Storage is stable and within height limits',
      'Lighting is adequate in all work areas',
    ],
    InspectionType.fireSafety: [
      'Fire extinguishers are present, charged, and unobstructed',
      'Emergency exits are unlocked and unobstructed',
      'Exit signage is visible and illuminated',
      'Fire alarm call points are accessible',
      'Flammable materials are stored correctly',
    ],
    InspectionType.ppe: [
      'Required PPE is available for the task',
      'PPE is in good condition (no damage/wear)',
      'PPE signage is displayed where required',
      'Workers are wearing PPE correctly',
      'PPE is stored and maintained appropriately',
    ],
    InspectionType.vehicle: [
      'Tyres, brakes, and lights are functional',
      'Seatbelts and safety devices work',
      'No fluid leaks observed',
      'Warning devices (horn/beacon) function',
      'Vehicle documentation is current',
    ],
    InspectionType.equipment: [
      'Guards and safety devices are fitted and functional',
      'Emergency stop is accessible and works',
      'No visible damage or defects',
      'Maintenance/inspection tag is current',
      'Operating area is clear and safe',
    ],
  };

  static List<String> forType(InspectionType type) => byType[type] ?? const [];
}
