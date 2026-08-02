// path: lib/features/user_admin/domain/user_lifecycle.dart
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';

/// Admin lifecycle actions.
enum UserAction { suspend, reactivate, deactivate, resendInvite, resetPassword }

/// Client-side mirror of the lifecycle state machine (server Edge Function is
/// authoritative — see supabase/functions/user-admin). Used to disable illegal
/// actions in the UI and fail fast in use cases.
abstract final class UserLifecycle {
  static const Map<UserStatus, Set<UserStatus>> allowed = {
    UserStatus.invited: {UserStatus.active, UserStatus.deactivated},
    UserStatus.active: {UserStatus.suspended, UserStatus.deactivated},
    UserStatus.suspended: {UserStatus.active, UserStatus.deactivated},
    UserStatus.deactivated: {UserStatus.active},
  };

  static bool canTransition(UserStatus from, UserStatus to) =>
      allowed[from]?.contains(to) ?? false;

  /// Target status for a status-changing action, or null for non-status actions.
  static UserStatus? targetFor(UserAction action) => switch (action) {
        UserAction.suspend => UserStatus.suspended,
        UserAction.reactivate => UserStatus.active,
        UserAction.deactivate => UserStatus.deactivated,
        UserAction.resendInvite || UserAction.resetPassword => null,
      };

  static bool canPerform(UserAction action, UserStatus from) {
    switch (action) {
      case UserAction.resendInvite:
        return from == UserStatus.invited;
      case UserAction.resetPassword:
        return from == UserStatus.active || from == UserStatus.suspended;
      case UserAction.suspend:
      case UserAction.reactivate:
      case UserAction.deactivate:
        final target = targetFor(action)!;
        return canTransition(from, target);
    }
  }
}
