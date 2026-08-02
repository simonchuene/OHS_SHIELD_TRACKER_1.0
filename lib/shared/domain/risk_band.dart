// path: lib/shared/domain/risk_band.dart
/// Locked risk banding (Master Prompt): 1–5 Low · 6–12 Medium · 13–17 High ·
/// 18–25 Critical. Shared by Hazard (risk_level) and Risk Assessment (Prompt 9)
/// so the mapping is defined once. Mirrors the DB `risk_band` enum + generated
/// column in risk_assessments.
enum RiskBand {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const RiskBand(this.dbValue);
  final String dbValue;

  static RiskBand? fromDb(String? v) => switch (v) {
        'low' => RiskBand.low,
        'medium' => RiskBand.medium,
        'high' => RiskBand.high,
        'critical' => RiskBand.critical,
        _ => null,
      };

  /// Maps a 1–25 score to its band (no gaps/overlaps across the full range).
  static RiskBand fromScore(int score) {
    if (score <= 5) return RiskBand.low;
    if (score <= 12) return RiskBand.medium;
    if (score <= 17) return RiskBand.high;
    return RiskBand.critical;
  }

  String get label => switch (this) {
        RiskBand.low => 'Low',
        RiskBand.medium => 'Medium',
        RiskBand.high => 'High',
        RiskBand.critical => 'Critical',
      };
}
