// path: lib/features/dashboard/presentation/providers/dashboard_providers.dart
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/data/dashboard_repository.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_data.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_providers.g.dart';

@riverpod
DashboardRepository dashboardRepository(DashboardRepositoryRef ref) => DashboardRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

/// Role-scoped dashboard snapshot for the signed-in user. Throws on hard failure
/// (no cache); returns a cached (offline) snapshot when the server is unreachable.
@riverpod
Future<DashboardData> dashboardData(DashboardDataRef ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) throw StateError('Not signed in');
  final res = await ref.watch(dashboardRepositoryProvider).load(role: user.primaryRole, userId: user.id);
  return res.when(ok: (d) => d, err: (f) => throw f);
}
