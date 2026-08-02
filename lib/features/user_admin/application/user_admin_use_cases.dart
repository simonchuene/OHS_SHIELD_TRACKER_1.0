// path: lib/features/user_admin/application/user_admin_use_cases.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/utils/validators.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/role_assignment.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/user_filter.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/user_lifecycle.dart';

/// Application layer for User & Access Administration. Status-changing use cases
/// fail fast on illegal transitions (server Edge Function re-enforces).
class UserAdminUseCases {
  const UserAdminUseCases(this._repo);
  final UserAdminRepository _repo;

  Future<Result<List<ManagedUser>>> list(UserFilter filter) => _repo.listUsers(filter);
  Future<Result<ManagedUser>> get(String userId) => _repo.getUser(userId);

  Future<Result<void>> invite(InviteUserParams params) {
    final emailError = Validators.email(params.email);
    if (emailError != null) {
      return Future.value(Err(ValidationFailure(emailError, fieldErrors: {'email': emailError})));
    }
    if (params.firstName.trim().isEmpty || params.lastName.trim().isEmpty) {
      return Future.value(const Err(ValidationFailure('First and last name are required.')));
    }
    return _repo.invite(params);
  }

  Future<Result<void>> resendInvite(ManagedUser user) => _guard(
        UserAction.resendInvite, user.status, () => _repo.resendInvite(user.id),);

  Future<Result<void>> assignRoles(String userId, List<RoleAssignment> roles) {
    if (roles.isEmpty) {
      return Future.value(const Err(ValidationFailure('Assign at least one role.')));
    }
    return _repo.assignRoles(userId, roles);
  }

  Future<Result<void>> suspend(ManagedUser user) =>
      _guard(UserAction.suspend, user.status, () => _repo.suspend(user.id));

  Future<Result<void>> reactivate(ManagedUser user) =>
      _guard(UserAction.reactivate, user.status, () => _repo.reactivate(user.id));

  Future<Result<void>> deactivate(ManagedUser user) =>
      _guard(UserAction.deactivate, user.status, () => _repo.deactivate(user.id));

  Future<Result<void>> resetPassword(ManagedUser user) => _guard(
        UserAction.resetPassword, user.status, () => _repo.resetPassword(user.id),);

  Future<Result<void>> _guard(
      UserAction action, UserStatus from, Future<Result<void>> Function() op,) {
    if (!UserLifecycle.canPerform(action, from)) {
      return Future.value(Err(ValidationFailure(
          'Cannot ${action.name} a user in "${from.code}" state.',),),);
    }
    return op();
  }
}
