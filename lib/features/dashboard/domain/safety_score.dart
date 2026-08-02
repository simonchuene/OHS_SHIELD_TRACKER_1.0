// path: lib/features/dashboard/domain/safety_score.dart
/// Composite site Safety Score (0–100) shown in the Risk Compass. MVP heuristic
/// (documented in docs/13): start at 100 and deduct weighted penalties for the
/// live risk drivers. Pure + testable; deterministic.
abstract final class SafetyScore {
  static const int highRiskWeight = 5; // per open High/Critical hazard
  static const int overdueCapaWeight = 4; // per overdue CAPA
  static const int seriousIncidentWeight = 6; // per Serious/Critical incident (30d)

  static int compute({
    required int highRiskHazards,
    required int overdueCapas,
    required int seriousIncidents30d,
  }) {
    final penalty = highRiskHazards * highRiskWeight +
        overdueCapas * overdueCapaWeight +
        seriousIncidents30d * seriousIncidentWeight;
    final score = 100 - penalty;
    return score.clamp(0, 100);
  }

  /// Trend copy helper: positive delta = improvement.
  static String trendLabel(int delta) =>
      delta > 0 ? 'Your score improved' : (delta < 0 ? 'Your score dropped' : 'No change');
}
