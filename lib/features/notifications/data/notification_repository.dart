// path: lib/features/notifications/data/notification_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/notifications/data/notification_dto.dart';
import 'package:ohs_shield_tracker/features/notifications/domain/app_notification.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notifications (RLS: recipient-only). Rows are created server-side by
/// `notify-fanout`; the client reads and marks read. Offline: server retains
/// notifications and they load on reconnect; FCM queues pushes.
final class NotificationRepository extends BaseRepository {
  NotificationRepository(this._client, LoggerService logger) : super(logger);
  final SupabaseClient _client;

  Future<Result<List<AppNotification>>> list() => run(() async {
        final rows = await _client.from('notifications').select().order('created_at', ascending: false).limit(100);
        return [for (final r in rows) NotificationDto.fromJson(r).toEntity()];
      }, context: 'listNotifications',);

  Future<Result<void>> markRead(String id) => run(() async {
        await _client.from('notifications').update({'is_read': true, 'read_at': DateTime.now().toIso8601String()}).eq('id', id);
      }, context: 'markRead',);

  Future<Result<void>> markAllRead() => run(() async {
        await _client.from('notifications').update({'is_read': true, 'read_at': DateTime.now().toIso8601String()}).eq('is_read', false);
      }, context: 'markAllRead',);

  /// Registers/refreshes this device's FCM token (RLS: user owns their tokens).
  Future<Result<void>> registerDeviceToken({
    required String token,
    required String platform,
    required String userId,
    required String companyId,
  }) =>
      run(() async {
        await _client.from('device_tokens').upsert({
          'user_id': userId, 'company_id': companyId, 'token': token,
          'platform': platform, 'is_active': true, 'last_seen_at': DateTime.now().toIso8601String(),
        }, onConflict: 'token',);
      }, context: 'registerDeviceToken',);
}
