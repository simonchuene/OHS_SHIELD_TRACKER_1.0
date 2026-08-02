// path: lib/features/hazards/domain/hazard_workflow.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';

/// Data the close guard needs, resolved from the DB before a transition is
/// attempted (kept out of the policy so the policy stays pure/testable).
class HazardGuardContext {
  const HazardGuardContext({
    this.hasVerificationEvidence = false,
    this.allLinkedCapasClosed = true,
  });
  final bool hasVerificationEvidence;
  final bool allLinkedCapasClosed;
}

/// Result of evaluating a transition.
class TransitionCheck {
  const TransitionCheck.allow() : allowed = true, reason = null;
  const TransitionCheck.deny(this.reason) : allowed = false;
  final bool allowed;
  final String? reason;
}

/// The Hazard Lifecycle state machine (Master Prompt STATUS GOVERNANCE):
/// Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed.
/// Forward-only, one adjacent step at a time. All rules are enforceable in code;
/// the server (`workflow-transition` Edge Function + RLS) re-enforces the guarded
/// ones authoritatively.
abstract final class HazardWorkflow {
  /// Adjacent forward transitions.
  static const Map<HazardStatus, HazardStatus> _forward = {
    HazardStatus.draft: HazardStatus.submitted,
    HazardStatus.submitted: HazardStatus.assessment,
    HazardStatus.assessment: HazardStatus.investigation,
    HazardStatus.investigation: HazardStatus.capa,
    HazardStatus.capa: HazardStatus.verification,
    HazardStatus.verification: HazardStatus.closed,
  };

  static HazardStatus? next(HazardStatus from) => _forward[from];

  /// Minimum role rank to move *into* [to] (per the RBAC matrix):
  /// report/submit = any (1); close = Safety Officer+ (3); everything else
  /// = Supervisor+ (2).
  static int minRankFor(HazardStatus to) => switch (to) {
        HazardStatus.submitted => AppRole.employee.rank, // 1 — reporter submits
        HazardStatus.closed => AppRole.safetyOfficer.rank, // 3
        _ => AppRole.supervisor.rank, // 2
      };

  /// The user-facing label for advancing from [from].
  static String? advanceLabel(HazardStatus from) => switch (next(from)) {
        HazardStatus.submitted => 'Submit',
        HazardStatus.assessment => 'Start assessment',
        HazardStatus.investigation => 'Start investigation',
        HazardStatus.capa => 'Move to CAPA',
        HazardStatus.verification => 'Move to verification',
        HazardStatus.closed => 'Close hazard',
        _ => null,
      };

  static bool requiresGuard(HazardStatus to) => to == HazardStatus.closed;

  /// Pure transition check. [guard] is required only when moving to Closed.
  static TransitionCheck canTransition({
    required HazardStatus from,
    required HazardStatus to,
    required int roleRank,
    HazardGuardContext? guard,
  }) {
    if (from.isClosed) return const TransitionCheck.deny('This hazard is closed.');
    if (_forward[from] != to) {
      return TransitionCheck.deny('Cannot move from ${from.label} to ${to.label}.');
    }
    if (roleRank < minRankFor(to)) {
      return TransitionCheck.deny('You do not have permission for this action.');
    }
    if (to == HazardStatus.closed) {
      final g = guard ?? const HazardGuardContext();
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
