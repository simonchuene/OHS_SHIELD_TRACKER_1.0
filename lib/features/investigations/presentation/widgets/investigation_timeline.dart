// path: lib/features/investigations/presentation/widgets/investigation_timeline.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';

/// Lightweight timeline derived from the investigation's own timestamps + status
/// (no audit_logs read — that is SO+ only and lives in the Audit Viewer, Prompt 16).
class InvestigationTimeline extends StatelessWidget {
  const InvestigationTimeline({required this.investigation, super.key});
  final Investigation investigation;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, DateTime?)>[
      ('Opened', investigation.openedAt),
      ('Current: ${investigation.status.label}', null),
      if (investigation.completedAt != null) ('Completed', investigation.completedAt),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Icon(
                investigation.isCompleted && i == entries.length - 1 ? Icons.check_circle_rounded : Icons.circle,
                size: 12,
                color: AppColors.primaryGreen,
              ),
              if (i != entries.length - 1) Container(width: 2, height: 24, color: AppColors.secondaryText),
            ],),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entries[i].$1),
                  if (entries[i].$2 != null)
                    Text(DateFormat.yMMMd().add_jm().format(entries[i].$2!),
                        style: Theme.of(context).textTheme.labelSmall,),
                ],),
              ),
            ),
          ],),
      ],
    );
  }
}
