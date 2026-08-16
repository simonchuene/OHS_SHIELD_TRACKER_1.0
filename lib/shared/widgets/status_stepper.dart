// path: lib/shared/widgets/status_stepper.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Horizontal progress trail for a linear workflow: completed steps tick green,
/// the current one is emphasised, later ones stay muted.
///
/// Takes labels and an index rather than a status enum, so every workflow can
/// use it without adding anything to its enum — the hazard version's `step` was
/// only ever `values.indexOf(this)`.
///
/// **Assumes a single linear path.** Every MVP1 workflow is a straight chain
/// (hazard, incident, CAPA, investigation, inspection). If one later gains a
/// branch or a rejection route, this becomes actively misleading rather than
/// merely incomplete, and would need rethinking rather than extending.
class StatusStepper extends StatelessWidget {
  const StatusStepper({required this.labels, required this.currentIndex, super.key});

  final List<String> labels;

  /// Position in [labels] of the current status. Everything at or before it
  /// reads as done.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    // Long workflows (hazard has seven steps) overflow a phone width, so the
    // trail scrolls rather than wrapping or shrinking the text.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          Icon(
            i <= currentIndex ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: i <= currentIndex ? AppColors.primaryGreen : AppColors.secondaryText,
          ),
          const SizedBox(width: 4),
          Text(
            labels[i],
            style: TextStyle(
              fontSize: 11,
              color: i == currentIndex ? context.primaryTextColor : AppColors.secondaryText,
            ),
          ),
          if (i != labels.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('›', style: TextStyle(color: AppColors.secondaryText)),
            ),
        ],
      ],),
    );
  }
}
