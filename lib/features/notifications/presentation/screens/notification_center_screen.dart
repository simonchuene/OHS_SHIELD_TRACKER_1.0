// path: lib/features/notifications/presentation/screens/notification_center_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/theme/app_colors.dart';
import 'package:ohs_shield_tracker/features/notifications/domain/app_notification.dart';
import 'package:ohs_shield_tracker/features/notifications/presentation/providers/notification_providers.dart';

/// Notification Center — in-app list with unread styling, mark-read, mark-all,
/// and deep-link on tap (Prompt 3 §9.5 notification states).
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationControllerProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load notifications: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("You're all caught up.")))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsListProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _Row(n: list[i]),
                ),
              ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: n.isRead ? null : const Border(left: BorderSide(color: AppColors.primaryGreen, width: 3)),
      ),
      child: ListTile(
        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700, color: n.isRead ? AppColors.secondaryText : AppColors.primaryText)),
        subtitle: Text('${n.body ?? ''}\n${DateFormat.MMMd().add_jm().format(n.createdAt)}', style: Theme.of(context).textTheme.labelSmall),
        isThreeLine: true,
        trailing: n.isHighPriority
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.criticalRed.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text(n.priority, style: const TextStyle(fontSize: 10, color: AppColors.criticalRed, fontWeight: FontWeight.w700)),
              )
            : null,
        onTap: () async {
          if (!n.isRead) await ref.read(notificationControllerProvider.notifier).markRead(n.id);
          final route = NotificationDeepLink.routeFor(n.entityType, n.entityId);
          if (route != null && context.mounted) unawaited(context.push(route));
        },
      ),
    );
  }
}
