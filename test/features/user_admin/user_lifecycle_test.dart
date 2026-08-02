// path: test/features/user_admin/user_lifecycle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/user_lifecycle.dart';

void main() {
  group('allowed transitions', () {
    test('invited -> active | deactivated only', () {
      expect(UserLifecycle.canTransition(UserStatus.invited, UserStatus.active), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.invited, UserStatus.deactivated), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.invited, UserStatus.suspended), isFalse);
    });
    test('active -> suspended | deactivated only', () {
      expect(UserLifecycle.canTransition(UserStatus.active, UserStatus.suspended), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.active, UserStatus.deactivated), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.active, UserStatus.invited), isFalse);
    });
    test('suspended -> active | deactivated', () {
      expect(UserLifecycle.canTransition(UserStatus.suspended, UserStatus.active), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.suspended, UserStatus.deactivated), isTrue);
    });
    test('deactivated -> active only (reactivate)', () {
      expect(UserLifecycle.canTransition(UserStatus.deactivated, UserStatus.active), isTrue);
      expect(UserLifecycle.canTransition(UserStatus.deactivated, UserStatus.suspended), isFalse);
    });
  });

  group('canPerform action guards', () {
    test('suspend only from active', () {
      expect(UserLifecycle.canPerform(UserAction.suspend, UserStatus.active), isTrue);
      expect(UserLifecycle.canPerform(UserAction.suspend, UserStatus.invited), isFalse);
      expect(UserLifecycle.canPerform(UserAction.suspend, UserStatus.deactivated), isFalse);
    });
    test('reactivate from suspended or deactivated', () {
      expect(UserLifecycle.canPerform(UserAction.reactivate, UserStatus.suspended), isTrue);
      expect(UserLifecycle.canPerform(UserAction.reactivate, UserStatus.deactivated), isTrue);
      expect(UserLifecycle.canPerform(UserAction.reactivate, UserStatus.active), isFalse);
    });
    test('deactivate from invited/active/suspended, not already deactivated', () {
      expect(UserLifecycle.canPerform(UserAction.deactivate, UserStatus.active), isTrue);
      expect(UserLifecycle.canPerform(UserAction.deactivate, UserStatus.invited), isTrue);
      expect(UserLifecycle.canPerform(UserAction.deactivate, UserStatus.suspended), isTrue);
      expect(UserLifecycle.canPerform(UserAction.deactivate, UserStatus.deactivated), isFalse);
    });
    test('resend invite only while invited', () {
      expect(UserLifecycle.canPerform(UserAction.resendInvite, UserStatus.invited), isTrue);
      expect(UserLifecycle.canPerform(UserAction.resendInvite, UserStatus.active), isFalse);
    });
  });
}
