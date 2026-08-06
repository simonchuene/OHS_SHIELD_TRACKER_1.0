// path: lib/shared/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';

/// Shown when a screen is rendering its last cached snapshot because the server
/// couldn't be reached. Explains what the user is looking at, how old it is, and
/// offers a retry — rather than stating a bare technical fact.
///
/// The wording deliberately avoids claiming "you're offline": a cache fallback
/// also happens when the device has a connection but the server is unreachable.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.lastUpdated, this.onRetry, super.key});

  /// When the cached snapshot was generated.
  final DateTime lastUpdated;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Amber reads as "heads-up, not an error". The deep amber is legible on a
    // light tint; on dark surfaces the token itself has the contrast.
    final accent = isDark ? AppColors.warningAmber : const Color(0xFF8A5A00);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: isDark ? 0.12 : 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.cloud_off_rounded, size: 20, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text("You're seeing saved data",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),),
            const SizedBox(height: 2),
            Text('Last updated ${friendlyTimeAgo(lastUpdated)}',
                style: TextStyle(fontSize: 11.5, color: accent.withValues(alpha: 0.85)),),
          ],),
        ),
        if (onRetry != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ],),
    );
  }
}

/// Human-readable age, e.g. "just now", "12 minutes ago", "yesterday".
/// Falls back to an absolute date once it's older than a week, where a relative
/// figure stops being meaningful.
String friendlyTimeAgo(DateTime when, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);

  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes == 1) return 'a minute ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
  if (diff.inHours == 1) return 'an hour ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return 'on ${DateFormat.yMMMd().format(when)}';
}
