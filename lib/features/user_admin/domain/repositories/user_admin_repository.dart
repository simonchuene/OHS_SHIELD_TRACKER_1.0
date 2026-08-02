// path: lib/features/user_admin/domain/repositories/user_admin_repository.dart
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/role_assignment.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/user_filter.dart';

/// Admin-only user lifecycle contract. Read paths (list/get) use RLS-scoped
/// PostgREST; all mutations are delegated to the service-role Edge Function
/// (`user-admin`) and therefore require connectivity.
abstract interface class UserAdminRepository {
  Future<Result<List<ManagedUser>>> listUsers(UserFilter filter);
  Future<Result<ManagedUser>> getUser(String userId);

  Future<Result<void>> invite(InviteUserParams params);
  Future<Result<void>> resendInvite(String userId);
  Future<Result<void>> assignRoles(String userId, List<RoleAssignment> roles);
  Future<Result<void>> suspend(String userId);
  Future<Result<void>> reactivate(String userId);
  Future<Result<void>> deactivate(String userId);
  Future<Result<void>> resetPassword(String userId);
}
