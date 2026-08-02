// path: lib/features/notifications/domain/app_notification.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';

/// An in-app notification (row from `notifications`).
@freezed
class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    required String triggerType,
    required String priority,
    required String title,
    String? body,
    String? entityType,
    String? entityId,
    @Default(false) bool isRead,
    required DateTime createdAt,
  }) = _AppNotification;

  bool get isHighPriority => priority == 'high' || priority == 'critical';
  bool get hasTarget => entityType != null && entityId != null;
}

/// Maps a notification's target entity to an in-app route (deep linking).
abstract final class NotificationDeepLink {
  static String? routeFor(String? entityType, String? entityId) {
    if (entityType == null || entityId == null) return null;
    return switch (entityType) {
      'hazard' => '/hazards/$entityId',
      'incident' => '/incidents/$entityId',
      'investigation' => '/investigations/$entityId',
      'corrective_action' => '/capa/$entityId',
      'inspection' => '/inspections/$entityId/run',
      _ => null,
    };
  }
}
