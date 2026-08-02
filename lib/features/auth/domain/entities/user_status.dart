// path: lib/features/auth/domain/entities/user_status.dart
/// User lifecycle (MVP1_2.md USER MANAGEMENT & PROVISIONING; enum `user_status`).
/// invited -> active -> suspended -> deactivated. Only `active` may sign in.
enum UserStatus {
  invited('invited'),
  active('active'),
  suspended('suspended'),
  deactivated('deactivated');

  const UserStatus(this.code);
  final String code;

  static UserStatus fromCode(String? code) => UserStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => UserStatus.deactivated,
      );

  bool get canSignIn => this == UserStatus.active;
}
