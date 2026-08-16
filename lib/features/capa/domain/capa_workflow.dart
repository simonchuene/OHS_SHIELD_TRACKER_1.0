// path: lib/features/capa/domain/capa_workflow.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;

/// Guard data resolved before a transition.
class CapaGuardContext {
  const CapaGuardContext({this.hasOwner = false, this.hasVerificationEvidence = false, this.isOwner = false});
  final bool hasOwner;
  final bool hasVerificationEvidence;

  /// Whether the acting user is this CAPA's assigned owner — lets them start work
  /// on their own action without needing Supervisor rank.
  final bool isOwner;
}

/// CAPA lifecycle: Created → Assigned → In Progress → Verification → Closed.
/// Role gates align with the RBAC matrix + RLS (2B): Create/Assign = Supervisor+;
/// **Verification and Closed = Safety Officer+**. Assign requires an owner;
/// Close requires verification evidence.
abstract final class CapaWorkflow {
  static const Map<CapaStatus, CapaStatus> _forward = {
    CapaStatus.created: CapaStatus.assigned,
    CapaStatus.assigned: CapaStatus.inProgress,
    CapaStatus.inProgress: CapaStatus.verification,
    CapaStatus.verification: CapaStatus.closed,
  };

  static CapaStatus? next(CapaStatus from) => _forward[from];

  /// Aligns with RLS `capa_update` WITH CHECK (verification/closed ⇒ rank≥3).
  static int minRankFor(CapaStatus to) =>
      (to == CapaStatus.verification || to == CapaStatus.closed)
          ? AppRole.safetyOfficer.rank
          : AppRole.supervisor.rank;

  static String? advanceLabel(CapaStatus from) => switch (next(from)) {
        CapaStatus.assigned => 'Assign',
        CapaStatus.inProgress => 'Start work',
        CapaStatus.verification => 'Submit for verification',
        CapaStatus.closed => 'Verify & close',
        _ => null,
      };

  static TransitionCheck canTransition({
    required CapaStatus from,
    required CapaStatus to,
    required int roleRank,
    CapaGuardContext? guard,
  }) {
    if (from.isClosed) return const TransitionCheck.deny('This action is closed.');
    if (_forward[from] != to) {
      return TransitionCheck.deny('Cannot move from ${from.label} to ${to.label}.');
    }
    final g = guard ?? const CapaGuardContext();
    // The assigned owner may run their own action through the doing phase
    // without a rank: Assigned → In Progress (0016) and In Progress →
    // Verification (0018, "I have finished, please check"). Closing still
    // requires Safety Officer+, so an owner can neither verify nor close their
    // own work — the separation of duties that matters is intact.
    final ownerDoingOwnWork =
        g.isOwner && (to == CapaStatus.inProgress || to == CapaStatus.verification);
    if (roleRank < minRankFor(to) && !ownerDoingOwnWork) {
      return const TransitionCheck.deny('You do not have permission for this action.');
    }
    if (to == CapaStatus.assigned && !g.hasOwner) {
      return const TransitionCheck.deny('Assign an owner first.');
    }
    if (to == CapaStatus.closed && !g.hasVerificationEvidence) {
      return const TransitionCheck.deny('Attach verification evidence before closing.');
    }
    return const TransitionCheck.allow();
  }
}
