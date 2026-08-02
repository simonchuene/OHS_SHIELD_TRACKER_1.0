// path: test/features/auth/app_role_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';

void main() {
  test('fromCode maps DB role codes to the right rank', () {
    expect(AppRole.fromCode('employee').rank, 1);
    expect(AppRole.fromCode('supervisor').rank, 2);
    expect(AppRole.fromCode('safety_officer').rank, 3);
    expect(AppRole.fromCode('manager').rank, 4);
    expect(AppRole.fromCode('administrator').rank, 5);
  });

  test('unknown code defaults to employee (least privilege)', () {
    expect(AppRole.fromCode('root'), AppRole.employee);
  });

  test('capability thresholds match the permission matrix', () {
    expect(AppRole.employee.canAssess, isFalse);
    expect(AppRole.supervisor.canAssess, isTrue);
    expect(AppRole.supervisor.canVerifyClose, isFalse);
    expect(AppRole.safetyOfficer.canVerifyClose, isTrue);
    expect(AppRole.safetyOfficer.canAdministerUsers, isFalse);
    expect(AppRole.administrator.canAdministerUsers, isTrue);
  });
}
