// path: lib/features/hazards/domain/entities/hazard_category.dart
/// Locked hazard categories (Master Prompt). `dbValue` matches the
/// `hazard_category` Postgres enum.
enum HazardCategory {
  physical('physical', 'Physical'),
  chemical('chemical', 'Chemical'),
  biological('biological', 'Biological'),
  ergonomic('ergonomic', 'Ergonomic'),
  psychosocial('psychosocial', 'Psychosocial'),
  noise('noise', 'Noise'),
  radiation('radiation', 'Radiation'),
  environmental('environmental', 'Environmental');

  const HazardCategory(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static HazardCategory fromDb(String v) =>
      HazardCategory.values.firstWhere((e) => e.dbValue == v, orElse: () => HazardCategory.physical);
}
