// path: lib/features/auth/data/dtos/user_profile_dto.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';

part 'user_profile_dto.freezed.dart';
part 'user_profile_dto.g.dart';

/// PostgREST row for `user_profiles`. Field names map to snake_case columns.
@freezed
class UserProfileDto with _$UserProfileDto {
  const UserProfileDto._();

  const factory UserProfileDto({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'company_id') required String companyId,
    @JsonKey(name: 'site_id') String? siteId,
    @JsonKey(name: 'department_id') String? departmentId,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    @JsonKey(name: 'job_title') String? jobTitle,
    String? phone,
    @JsonKey(name: 'avatar_path') String? avatarPath,
    required String status,
  }) = _UserProfileDto;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDtoFromJson(json);

  /// Combine the profile row with resolved role codes into a domain [AppUser].
  AppUser toEntity({required String email, required List<String> roleCodes}) {
    return AppUser(
      id: userId,
      email: email,
      companyId: companyId,
      siteId: siteId,
      departmentId: departmentId,
      firstName: firstName,
      lastName: lastName,
      status: UserStatus.fromCode(status),
      roles: roleCodes.map(AppRole.fromCode).toList(),
    );
  }
}
