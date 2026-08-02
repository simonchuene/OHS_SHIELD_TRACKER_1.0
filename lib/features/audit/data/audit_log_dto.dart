// path: lib/features/audit/data/audit_log_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/audit/domain/audit_log_entry.dart';

part 'audit_log_dto.freezed.dart';
part 'audit_log_dto.g.dart';

@freezed
class AuditLogDto with _$AuditLogDto {
  const AuditLogDto._();

  const factory AuditLogDto({
    required String id,
    @JsonKey(name: 'actor_id') String? actorId,
    required String action,
    @JsonKey(name: 'entity_type') required String entityType,
    @JsonKey(name: 'entity_id') String? entityId,
    @JsonKey(name: 'before_state') Map<String, dynamic>? beforeState,
    @JsonKey(name: 'after_state') Map<String, dynamic>? afterState,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _AuditLogDto;

  factory AuditLogDto.fromJson(Map<String, dynamic> json) => _$AuditLogDtoFromJson(json);

  AuditLogEntry toEntity() => AuditLogEntry(
        id: id, actorId: actorId, action: action, entityType: entityType, entityId: entityId,
        beforeState: beforeState, afterState: afterState, createdAt: DateTime.parse(createdAt),
      );
}
