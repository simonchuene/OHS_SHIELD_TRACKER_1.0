// path: lib/shared/widgets/sync_status_badge.dart
import 'package:flutter/material.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/services/sync/sync_models.dart';

/// Per-record sync indicator (Prompt 3 §9.4): pending (amber clock),
/// syncing (blue spinner), synced (green check), failed (red retry).
class SyncBadge extends StatelessWidget {
  const SyncBadge({required this.status, this.compact = true, super.key});
  final SyncStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      SyncStatus.pending => (Icons.schedule_rounded, AppColors.warningAmber, 'Pending'),
      SyncStatus.syncing => (Icons.sync_rounded, AppColors.infoBlue, 'Syncing'),
      SyncStatus.synced => (Icons.check_circle_rounded, AppColors.primaryGreen, 'Synced'),
      SyncStatus.failed => (Icons.error_outline_rounded, AppColors.criticalRed, 'Failed'),
    };
    if (compact) {
      return Tooltip(message: label, child: Icon(icon, size: 16, color: color));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],),
    );
  }
}
