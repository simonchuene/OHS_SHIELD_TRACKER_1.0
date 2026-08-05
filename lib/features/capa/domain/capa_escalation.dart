// path: lib/features/capa/domain/capa_escalation.dart
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';

enum CapaEscalation { none, dueSoon, overdue, critical }

/// Due-date escalation for open CAPAs. Critical priority always escalates;
/// otherwise overdue (past due) / due-soon (within [dueSoonDays]).
abstract final class CapaEscalationRules {
  static const int dueSoonDays = 2;

  static CapaEscalation evaluate(CorrectiveAction capa, DateTime now) {
    if (capa.isClosed) return CapaEscalation.none;
    if (capa.priority == CapaPriority.critical) return CapaEscalation.critical;
    final due = capa.dueDate;
    if (due == null) return CapaEscalation.none;
    // Overdue only once the due day has fully elapsed (from the next day).
    if (CorrectiveAction.isPastDue(due, now: now)) return CapaEscalation.overdue;
    if (due.difference(now).inDays <= dueSoonDays) return CapaEscalation.dueSoon;
    return CapaEscalation.none;
  }

  /// Overdue or critical raise a notification (`capa.overdue`; wired in Prompt 15).
  static bool shouldNotify(CapaEscalation e) => e == CapaEscalation.overdue || e == CapaEscalation.critical;
}
