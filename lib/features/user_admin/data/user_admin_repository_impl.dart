// path: lib/features/user_admin/data/user_admin_repository_impl.dart
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/app_role.dart';
import 'package:ohs_shield_tracker/features/auth/domain/entities/user_status.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/role_assignment.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/user_filter.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:ohs_shield_tracker/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _selectGraph = '*, users(email), user_roles(site_id, department_id, roles(code))';

final class UserAdminRepositoryImpl extends BaseRepository implements UserAdminRepository {
  UserAdminRepositoryImpl(this._client, LoggerService logger) : super(logger);

  final SupabaseClient _client;

  @override
  Future<Result<List<ManagedUser>>> listUsers(UserFilter filter) {
    return run(() async {
      var query = _client.from('user_profiles').select(_selectGraph);
      if (filter.status != null) query = query.eq('status', filter.status!.code);
      if (filter.siteId != null) query = query.eq('site_id', filter.siteId!);
      if (filter.departmentId != null) query = query.eq('department_id', filter.departmentId!);

      final rows = await query.order('first_name');
      var users = rows.map(_map).toList();

      // Role + free-text filters applied client-side (company user counts are small).
      if (filter.role != null) {
        users = users.where((u) => u.roles.any((r) => r.role == filter.role)).toList();
      }
      final q = filter.query?.trim().toLowerCase();
      if (q != null && q.isNotEmpty) {
        users = users
            .where((u) =>
                u.displayName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q),)
            .toList();
      }
      return users;
    }, context: 'listUsers',);
  }

  @override
  Future<Result<ManagedUser>> getUser(String userId) {
    return run(() async {
      final row = await _client.from('user_profiles').select(_selectGraph).eq('user_id', userId).single();
      return _map(row);
    }, context: 'getUser',);
  }

  @override
  Future<Result<void>> invite(InviteUserParams params) =>
      _invoke(params.toInvitePayload(), ctx: 'invite');

  @override
  Future<Result<void>> resendInvite(String userId) =>
      _invoke({'action': 'resendInvite', 'userId': userId}, ctx: 'resendInvite');

  @override
  Future<Result<void>> assignRoles(String userId, List<RoleAssignment> roles) => _invoke({
        'action': 'assignRoles',
        'userId': userId,
        'roles': [
          for (final r in roles)
            {'role': r.role.code, 'siteId': r.siteId, 'departmentId': r.departmentId},
        ],
      }, ctx: 'assignRoles',);

  @override
  Future<Result<void>> suspend(String userId) =>
      _invoke({'action': 'suspend', 'userId': userId}, ctx: 'suspend');

  @override
  Future<Result<void>> reactivate(String userId) =>
      _invoke({'action': 'reactivate', 'userId': userId}, ctx: 'reactivate');

  @override
  Future<Result<void>> deactivate(String userId) =>
      _invoke({'action': 'deactivate', 'userId': userId}, ctx: 'deactivate');

  @override
  Future<Result<void>> resetPassword(String userId) =>
      _invoke({'action': 'resetPassword', 'userId': userId}, ctx: 'resetPassword');

  /// All privileged mutations go through the service-role Edge Function.
  Future<Result<void>> _invoke(Map<String, dynamic> body, {required String ctx}) async {
    try {
      final res = await _client.functions.invoke('user-admin', body: body);
      final data = res.data;
      if (res.status >= 400 || (data is Map && data['error'] != null)) {
        final msg = (data is Map ? data['error']?.toString() : null) ?? 'Request failed';
        logger.warn('user-admin $ctx failed: $msg');
        return Err(ServerFailure(msg));
      }
      return const Ok(null);
    } on FunctionException catch (e) {
      final msg = (e.details is Map ? (e.details as Map)['error']?.toString() : null) ?? 'Request failed';
      logger.warn('user-admin $ctx FunctionException: $msg');
      return Err(ServerFailure(msg));
    } catch (e, s) {
      logger.error('user-admin $ctx error', e, s);
      return const Err(NetworkFailure());
    }
  }

  ManagedUser _map(Map<String, dynamic> row) {
    final email = (row['users'] as Map?)?['email']?.toString() ?? '';
    final roleRows = (row['user_roles'] as List?) ?? const [];
    final roles = <RoleAssignment>[
      for (final r in roleRows)
        RoleAssignment(
          role: AppRole.fromCode(((r['roles'] as Map?)?['code'] ?? 'employee').toString()),
          siteId: r['site_id'] as String?,
          departmentId: r['department_id'] as String?,
        ),
    ];
    return ManagedUser(
      id: row['user_id'] as String,
      email: email,
      firstName: (row['first_name'] ?? '').toString(),
      lastName: (row['last_name'] ?? '').toString(),
      jobTitle: row['job_title'] as String?,
      phone: row['phone'] as String?,
      siteId: row['site_id'] as String?,
      departmentId: row['department_id'] as String?,
      status: UserStatus.fromCode(row['status'] as String?),
      roles: roles,
    );
  }
}
