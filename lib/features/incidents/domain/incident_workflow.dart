// path: lib/features/incidents/domain/incident_workflow.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';

class IncidentGuardContext {
  const IncidentGuardContext({this.hasVerificationEvidence = false, this.allLinkedCapasClosed = true});
  final bool hasVerificationEvidence;
  final bool allLinkedCapasClosed;
}

/// Incident lifecycle (Master Prompt): Reported → Investigated → CAPA → Verified
/// → Closed. Forward-only, adjacent. Close requires Safety Officer+ AND
/// verification evidence AND all linked CAPAs closed. Server (`workflow-transition`
/// Edge Function + RLS) re-enforces authoritatively.
abstract final class IncidentWorkflow {
  static const Map<IncidentStatus, IncidentStatus> _forward = {
    IncidentStatus.reported: IncidentStatus.investigated,
    IncidentStatus.investigated: IncidentStatus.capa,
    IncidentStatus.capa: IncidentStatus.verified,
    IncidentStatus.verified: IncidentStatus.closed,
  };

  static IncidentStatus? next(IncidentStatus from) => _forward[from];

  static int minRankFor(IncidentStatus to) =>
      to == IncidentStatus.closed ? AppRole.safetyOfficer.rank : AppRole.supervisor.rank;

  static String? advanceLabel(IncidentStatus from) => switch (next(from)) {
        IncidentStatus.investigated => 'Mark investigated',
        IncidentStatus.capa => 'Move to CAPA',
        IncidentStatus.verified => 'Move to verification',
        IncidentStatus.closed => 'Close incident',
        _ => null,
      };

  static TransitionCheck canTransition({
    required IncidentStatus from,
    required IncidentStatus to,
    required int roleRank,
    IncidentGuardContext? guard,
  }) {
    if (from.isClosed) return const TransitionCheck.deny('This incident is closed.');
    if (_forward[from] != to) {
      return TransitionCheck.deny('Cannot move from ${from.label} to ${to.label}.');
    }
    if (roleRank < minRankFor(to)) {
      return const TransitionCheck.deny('You do not have permission for this action.');
    }
    if (to == IncidentStatus.closed) {
      final g = guard ?? const IncidentGuardContext();
      if (!g.hasVerificationEvidence) {
        return const TransitionCheck.deny('Attach verification evidence before closing.');
      }
      if (!g.allLinkedCapasClosed) {
        return const TransitionCheck.deny('All linked corrective actions must be closed first.');
      }
    }
    return const TransitionCheck.allow();
  }
}
