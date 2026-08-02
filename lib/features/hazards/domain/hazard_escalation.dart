// path: lib/features/hazards/domain/hazard_escalation.dart
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/shared/domain/risk_band.dart';

enum EscalationLevel { none, dueSoon, overdue, critical }

/// Pure escalation rules for open hazards. Critical-risk hazards always escalate;
/// otherwise a stage-based SLA drives due-soon/overdue. (MVP proxies stage age
/// from `reportedAt`; per-stage entry timestamps are a future refinement — see
/// docs/08.)
abstract final class HazardEscalation {
  /// Working-day SLA per active stage.
  static const Map<HazardStatus, int> stageSlaDays = {
    HazardStatus.submitted: 2,
    HazardStatus.assessment: 3,
    HazardStatus.investigation: 5,
    HazardStatus.capa: 7,
    HazardStatus.verification: 3,
  };

  static EscalationLevel evaluate(Hazard hazard, DateTime now) {
    if (hazard.isClosed) return EscalationLevel.none;
    if (hazard.riskLevel == RiskBand.critical) return EscalationLevel.critical;

    final sla = stageSlaDays[hazard.status];
    if (sla == null) return EscalationLevel.none;

    final ageDays = now.difference(hazard.reportedAt).inDays;
    if (ageDays > sla) return EscalationLevel.overdue;
    if (ageDays >= sla - 1) return EscalationLevel.dueSoon;
    return EscalationLevel.none;
  }

  /// Whether escalation should raise a notification (consumed as a stub now,
  /// wired to FCM/in-app in Prompt 15).
  static bool shouldNotify(EscalationLevel level) =>
      level == EscalationLevel.overdue || level == EscalationLevel.critical;
}
