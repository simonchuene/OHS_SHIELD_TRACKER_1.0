// path: lib/features/notifications/data/notification_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/notifications/domain/app_notification.dart';

part 'notification_dto.freezed.dart';
part 'notification_dto.g.dart';

@freezed
class NotificationDto with _$NotificationDto {
  const NotificationDto._();

  const factory NotificationDto({
    required String id,
    @JsonKey(name: 'trigger_type') required String triggerType,
    @Default('normal') String priority,
    required String title,
    String? body,
    @JsonKey(name: 'entity_type') String? entityType,
    @JsonKey(name: 'entity_id') String? entityId,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _NotificationDto;

  factory NotificationDto.fromJson(Map<String, dynamic> json) => _$NotificationDtoFromJson(json);

  AppNotification toEntity() => AppNotification(
        id: id, triggerType: triggerType, priority: priority, title: title, body: body,
        entityType: entityType, entityId: entityId, isRead: isRead, createdAt: DateTime.parse(createdAt),
      );
}
