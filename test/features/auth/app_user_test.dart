// path: test/features/auth/app_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_user.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';

void main() {
  AppUser make({List<AppRole> roles = const [], UserStatus status = UserStatus.active}) => AppUser(
        id: 'u1',
        email: 'lindokuhle@acme.com',
        companyId: 'c1',
        firstName: 'Lindokuhle',
        lastName: 'Mkhize',
        status: status,
        roles: roles,
      );

  test('highestRank picks the strongest of multiple scope-aware roles', () {
    final u = make(roles: [AppRole.supervisor, AppRole.manager, AppRole.employee]);
    expect(u.highestRank, 4);
    expect(u.primaryRole, AppRole.manager);
  });

  test('no roles -> rank 0', () {
    expect(make().highestRank, 0);
    expect(make().primaryRole, isNull);
  });

  test('initials and displayName', () {
    final u = make();
    expect(u.initials, 'LM');
    expect(u.displayName, 'Lindokuhle Mkhize');
  });

  test('only active users may sign in', () {
    expect(make().isActive, isTrue);
    expect(make(status: UserStatus.suspended).isActive, isFalse);
    expect(make(status: UserStatus.deactivated).isActive, isFalse);
    expect(make(status: UserStatus.invited).isActive, isFalse);
  });
}
