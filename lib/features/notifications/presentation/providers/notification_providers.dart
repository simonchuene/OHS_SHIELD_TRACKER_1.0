// path: lib/features/notifications/presentation/providers/notification_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/notifications/data/fcm_service.dart';
import 'package:ohs_shield_tracker/features/notifications/data/notification_repository.dart';
import 'package:ohs_shield_tracker/features/notifications/domain/app_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_providers.g.dart';

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) =>
    NotificationRepository(ref.watch(supabaseClientProvider), ref.watch(loggerProvider));

@riverpod
FcmService fcmService(FcmServiceRef ref) => FcmService(ref.watch(loggerProvider));

@riverpod
Future<List<AppNotification>> notificationsList(NotificationsListRef ref) async {
  final res = await ref.watch(notificationRepositoryProvider).list();
  return res.when(ok: (n) => n, err: (f) => throw f);
}

/// Unread count for the More/Notifications badge.
@riverpod
int unreadNotificationCount(UnreadNotificationCountRef ref) =>
    ref.watch(notificationsListProvider).valueOrNull?.where((n) => !n.isRead).length ?? 0;

@riverpod
class NotificationController extends _$NotificationController {
  @override
  FutureOr<void> build() {}

  Future<bool> markRead(String id) async {
    final res = await ref.read(notificationRepositoryProvider).markRead(id);
    return res.when(ok: (_) { ref.invalidate(notificationsListProvider); return true; }, err: _err);
  }

  Future<bool> markAllRead() async {
    final res = await ref.read(notificationRepositoryProvider).markAllRead();
    return res.when(ok: (_) { ref.invalidate(notificationsListProvider); return true; }, err: _err);
  }

  /// Register this device for push + wire deep-link handling. Called after login.
  Future<void> registerForPush(void Function(String route) onDeepLink) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await ref.read(fcmServiceProvider).init(
      onToken: (token, platform) async {
        await ref.read(notificationRepositoryProvider).registerDeviceToken(
              token: token, platform: platform, userId: user.id, companyId: user.companyId,);
      },
      onDeepLink: onDeepLink,
    );
  }

  bool _err(Failure f) { state = AsyncError(f, StackTrace.current); return false; }
}
