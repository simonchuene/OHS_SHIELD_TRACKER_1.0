// path: lib/features/dashboard/presentation/providers/dashboard_providers.dart
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/dashboard/data/dashboard_repository.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/dashboard_data.dart';
import 'package:ohs_shield_tracker/features/dashboard/domain/priority_item.dart';
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
  // Await the user rather than reading valueOrNull: while the profile is still
  // loading, valueOrNull is null too, which flashed a spurious "Not signed in"
  // error on the home dashboard before the user resolved. Awaiting keeps the
  // dashboard on its loading state until the user is actually known; the error
  // only surfaces if genuinely signed out (router then redirects to login).
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) throw StateError('Not signed in');
  final res = await ref.watch(dashboardRepositoryProvider).load(role: user.primaryRole, userId: user.id);
  return res.when(ok: (d) => d, err: (f) => throw f);
}

/// The top open hazards/CAPAs/incidents needing attention, ranked by severity →
/// overdue → soonest due → most recently updated (see [PriorityItem.compare]).
/// RLS scopes the rows to the signed-in user's visibility.
@riverpod
Future<List<PriorityItem>> todaysPriorities(TodaysPrioritiesRef ref) async {
  await ref.watch(currentUserProvider.future); // hold loading until signed in
  final client = ref.watch(supabaseClientProvider);
  final results = await Future.wait([
    client.from('hazards').select('id,title,status,risk_level,location_text,updated_at').neq('status', 'closed'),
    client.from('corrective_actions').select('id,description,status,priority,due_date,updated_at').neq('status', 'closed'),
    client.from('incidents').select('id,description,incident_type,severity,status,location_text,updated_at').neq('status', 'closed'),
  ]);
  final items = <PriorityItem>[
    for (final h in results[0]) PriorityItem.fromHazard(h),
    for (final c in results[1]) PriorityItem.fromCapa(c),
    for (final i in results[2]) PriorityItem.fromIncident(i),
  ]..sort(PriorityItem.compare);
  return items.take(5).toList();
}
