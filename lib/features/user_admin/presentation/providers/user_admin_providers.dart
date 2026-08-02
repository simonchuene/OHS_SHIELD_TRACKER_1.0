// path: lib/features/user_admin/presentation/providers/user_admin_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/user_admin/application/user_admin_use_cases.dart';
import 'package:ohs_shield_tracker/features/user_admin/data/user_admin_repository_impl.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/managed_user.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/entities/user_filter.dart';
import 'package:ohs_shield_tracker/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_admin_providers.g.dart';

typedef NamedRef = ({String id, String name});

@riverpod
UserAdminRepository userAdminRepository(UserAdminRepositoryRef ref) =>
    UserAdminRepositoryImpl(ref.watch(supabaseClientProvider), ref.watch(loggerProvider));

@riverpod
UserAdminUseCases userAdminUseCases(UserAdminUseCasesRef ref) =>
    UserAdminUseCases(ref.watch(userAdminRepositoryProvider));

/// Current list filter (site/department/role/status/query).
@riverpod
class UserFilterController extends _$UserFilterController {
  @override
  UserFilter build() => const UserFilter();
  void update(UserFilter filter) => state = filter;
  void clear() => state = const UserFilter();
}

/// The filtered user list (reactive to [UserFilterController]).
@riverpod
Future<List<ManagedUser>> usersList(UsersListRef ref) async {
  final filter = ref.watch(userFilterControllerProvider);
  final res = await ref.watch(userAdminUseCasesProvider).list(filter);
  return res.when(ok: (u) => u, err: (f) => throw f);
}

@riverpod
Future<ManagedUser> userDetail(UserDetailRef ref, String userId) async {
  final res = await ref.watch(userAdminUseCasesProvider).get(userId);
  return res.when(ok: (u) => u, err: (f) => throw f);
}

/// Sites in the admin's company (invite form dropdown). RLS-scoped.
@riverpod
Future<List<NamedRef>> companySites(CompanySitesRef ref) async {
  final rows = await ref.watch(supabaseClientProvider).from('sites').select('id, name').order('name');
  return [for (final r in rows) (id: r['id'] as String, name: r['name'] as String)];
}

@riverpod
Future<List<NamedRef>> siteDepartments(SiteDepartmentsRef ref, String siteId) async {
  final rows = await ref
      .watch(supabaseClientProvider)
      .from('departments')
      .select('id, name')
      .eq('site_id', siteId)
      .order('name');
  return [for (final r in rows) (id: r['id'] as String, name: r['name'] as String)];
}

/// Executes privileged admin actions. Enforces connectivity (privileged ops run
/// via the service-role Edge Function and are NOT queued offline).
@riverpod
class UserAdminActionController extends _$UserAdminActionController {
  @override
  FutureOr<void> build() {}

  Future<bool> _run(Future<Result<void>> Function() op, {String? affectedUserId}) async {
    if (ref.read(connectivityStatusProvider).valueOrNull == false) {
      state = AsyncError(
        const NetworkFailure('This action needs an internet connection. Reconnect and try again.'),
        StackTrace.current,
      );
      return false;
    }
    state = const AsyncLoading();
    final res = await op();
    return res.when(
      ok: (_) {
        state = const AsyncData(null);
        ref.invalidate(usersListProvider);
        if (affectedUserId != null) ref.invalidate(userDetailProvider(affectedUserId));
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> invite(InviteUserParams params) =>
      _run(() => ref.read(userAdminUseCasesProvider).invite(params));

  Future<bool> resendInvite(ManagedUser u) =>
      _run(() => ref.read(userAdminUseCasesProvider).resendInvite(u), affectedUserId: u.id);

  Future<bool> suspend(ManagedUser u) =>
      _run(() => ref.read(userAdminUseCasesProvider).suspend(u), affectedUserId: u.id);

  Future<bool> reactivate(ManagedUser u) =>
      _run(() => ref.read(userAdminUseCasesProvider).reactivate(u), affectedUserId: u.id);

  Future<bool> deactivate(ManagedUser u) =>
      _run(() => ref.read(userAdminUseCasesProvider).deactivate(u), affectedUserId: u.id);

  Future<bool> resetPassword(ManagedUser u) =>
      _run(() => ref.read(userAdminUseCasesProvider).resetPassword(u), affectedUserId: u.id);
}
