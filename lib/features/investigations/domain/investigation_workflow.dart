// path: lib/features/investigations/domain/investigation_workflow.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';

/// Investigation lifecycle: Open → In Progress → Pending Review → Completed.
/// Forward-only, adjacent. Conducting an investigation is Supervisor+.
/// Completing requires a root cause AND recommendations (mandatory business rules).
abstract final class InvestigationWorkflow {
  static const Map<InvestigationStatus, InvestigationStatus> _forward = {
    InvestigationStatus.open: InvestigationStatus.inProgress,
    InvestigationStatus.inProgress: InvestigationStatus.pendingReview,
    InvestigationStatus.pendingReview: InvestigationStatus.completed,
  };

  static InvestigationStatus? next(InvestigationStatus from) => _forward[from];

  static int minRank() => AppRole.supervisor.rank; // Conduct Investigation = Supervisor+

  static String? advanceLabel(InvestigationStatus from) => switch (next(from)) {
        InvestigationStatus.inProgress => 'Begin',
        InvestigationStatus.pendingReview => 'Submit for review',
        InvestigationStatus.completed => 'Complete',
        _ => null,
      };

  static TransitionCheck canTransition({
    required Investigation investigation,
    required InvestigationStatus to,
    required int roleRank,
  }) {
    final from = investigation.status;
    if (from.isCompleted) return const TransitionCheck.deny('This investigation is completed.');
    if (_forward[from] != to) {
      return TransitionCheck.deny('Cannot move from ${from.label} to ${to.label}.');
    }
    if (roleRank < minRank()) {
      return const TransitionCheck.deny('You do not have permission for this action.');
    }
    if (to == InvestigationStatus.completed) {
      if (!investigation.hasRootCause) return const TransitionCheck.deny('A root cause is required to complete.');
      if (!investigation.hasRecommendations) return const TransitionCheck.deny('Recommendations are required to complete.');
    }
    return const TransitionCheck.allow();
  }
}
