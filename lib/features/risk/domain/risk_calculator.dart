// path: lib/features/risk/domain/risk_calculator.dart
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

/// Pure risk scoring (Master Prompt RISK ASSESSMENT). Score = Likelihood × Severity,
/// each 1–5; band per the locked table. No undefined scores across 1–25.
abstract final class RiskCalculator {
  static bool isValidFactor(int v) => v >= 1 && v <= 5;

  /// Risk score for a Likelihood/Severity pair (both 1–5).
  static int score(int likelihood, int severity) => likelihood * severity;

  /// Band for a raw score (delegates to the single shared banding rule).
  static RiskBand band(int score) => RiskBand.fromScore(score);

  static RiskBand bandFor(int likelihood, int severity) => band(score(likelihood, severity));

  /// Residual band from residual factors, or null if either is unset.
  static RiskBand? residualBand(int? likelihood, int? severity) {
    if (likelihood == null || severity == null) return null;
    return bandFor(likelihood, severity);
  }

  /// The 14 distinct products actually reachable from 1–5 × 1–5.
  static const List<int> reachableScores = [1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 15, 16, 20, 25];

  /// Default CAPA priority derived from the assigned band (Master Prompt Risk
  /// DoD: the level drives CAPA priority defaults). Values match `capa_priority`.
  static String defaultCapaPriority(RiskBand band) => switch (band) {
        RiskBand.critical => 'critical',
        RiskBand.high => 'high',
        RiskBand.medium => 'medium',
        RiskBand.low => 'low',
      };
}
