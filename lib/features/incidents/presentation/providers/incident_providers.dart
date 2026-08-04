// path: lib/features/incidents/presentation/providers/incident_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;
import 'package:ohs_shield_tracker/features/incidents/application/incident_use_cases.dart';
import 'package:ohs_shield_tracker/features/incidents/data/incident_repository_impl.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_enums.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/entities/incident_filter.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/incident_workflow.dart';
import 'package:ohs_shield_tracker/features/incidents/domain/repositories/incident_repository.dart';
import 'package:ohs_shield_tracker/services/notifications/notification_triggers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'incident_providers.g.dart';

@riverpod
IncidentRepository incidentRepository(IncidentRepositoryRef ref) => IncidentRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
IncidentUseCases incidentUseCases(IncidentUseCasesRef ref) =>
    IncidentUseCases(ref.watch(incidentRepositoryProvider));

@riverpod
class IncidentFilterController extends _$IncidentFilterController {
  @override
  IncidentFilter build() => const IncidentFilter();
  void update(IncidentFilter f) => state = f;
}

@riverpod
Future<List<Incident>> incidentList(IncidentListRef ref) async {
  final filter = ref.watch(incidentFilterControllerProvider);
  final uid = ref.watch(currentUserProvider).valueOrNull?.id;
  final res = await ref.watch(incidentUseCasesProvider).list(filter, uid: uid);
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
Future<Incident> incidentDetail(IncidentDetailRef ref, String id) async {
  final res = await ref.watch(incidentUseCasesProvider).get(id);
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
Future<IncidentGuardContext> incidentGuardContext(IncidentGuardContextRef ref, String incidentId) async {
  final client = ref.watch(supabaseClientProvider);
  final evidence = await client.from('attachments').select('id')
      .eq('owner_type', 'incident').eq('owner_id', incidentId).eq('is_active', true).limit(1);
  final openCapas = await client.from('corrective_actions').select('id')
      .eq('incident_id', incidentId).neq('status', 'closed').limit(1);
  return IncidentGuardContext(hasVerificationEvidence: evidence.isNotEmpty, allLinkedCapasClosed: openCapas.isEmpty);
}

@riverpod
class IncidentReportController extends _$IncidentReportController {
  @override
  FutureOr<Incident?> build() => null;

  Future<Incident?> submit(ReportIncidentParams params) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      state = AsyncError(const AuthFailure('You are signed out.'), StackTrace.current);
      return null;
    }
    state = const AsyncLoading();
    final res = await ref.read(incidentUseCasesProvider).report(params, companyId: user.companyId, reporterId: user.id);
    return res.when(
      ok: (i) {
        state = AsyncData(i);
        ref.invalidate(incidentListProvider);
        ref.read(notificationTriggersProvider).fire(NotificationTrigger.incidentCreated, entityType: 'incident', entityId: i.id);
        return i;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return null;
      },
    );
  }
}

/// Lifecycle + linkage actions. Close and linkage/generation require connectivity.
@riverpod
class IncidentActionController extends _$IncidentActionController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> advance(Incident incident) async {
    final to = IncidentWorkflow.next(incident.status);
    if (to == null) {
      state = AsyncError(const ValidationFailure('This incident is already closed.'), StackTrace.current);
      return false;
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    final rank = ref.read(authRoleRankProvider) ?? 0;
    if (user == null) return _fail(const AuthFailure('You are signed out.'));

    final guard = to == IncidentStatus.closed ? await ref.read(incidentGuardContextProvider(incident.id).future) : null;
    final TransitionCheck check = IncidentWorkflow.canTransition(from: incident.status, to: to, roleRank: rank, guard: guard);
    if (!check.allowed) return _fail(ValidationFailure(check.reason ?? 'Transition not allowed.'));

    state = const AsyncLoading();
    final ok = to == IncidentStatus.closed
        ? await _close(incident)
        : await _advanceOffline(incident, to, user.companyId, user.id);
    if (ok) {
      state = const AsyncData(null);
      _invalidate(incident.id);
    }
    return ok;
  }

  Future<bool> linkToHazard(Incident incident, String hazardId) => _online(() async {
        final res = await ref.read(incidentUseCasesProvider).linkToHazard(incident.id, hazardId);
        return res.when(ok: (_) { _invalidate(incident.id); return true; }, err: _errBool);
      });

  Future<bool> generateInvestigation(Incident incident) => _online(() async {
        final user = ref.read(currentUserProvider).valueOrNull!;
        final res = await ref.read(incidentUseCasesProvider)
            .generateInvestigation(incident.id, user.companyId, user.id, siteId: incident.siteId);
        return res.when(ok: (_) { _invalidate(incident.id); return true; }, err: _errBool);
      });

  Future<bool> generateCapa(Incident incident, String description, String priority) => _online(() async {
        final user = ref.read(currentUserProvider).valueOrNull!;
        final res = await ref.read(incidentUseCasesProvider)
            .generateCapa(incident.id, user.companyId, description, priority, siteId: incident.siteId);
        return res.when(ok: (_) { _invalidate(incident.id); return true; }, err: _errBool);
      });

  Future<bool> _advanceOffline(Incident i, IncidentStatus to, String companyId, String userId) async {
    final res = await ref.read(incidentUseCasesProvider).update(
        id: i.id, changes: {'status': to.dbValue}, baseVersion: i.version, companyId: companyId, userId: userId,);
    return res.when(ok: (_) => true, err: _errBool);
  }

  Future<bool> _close(Incident i) => _online(() async {
        final res = await ref.read(supabaseClientProvider).functions
            .invoke('workflow-transition', body: {'entityType': 'incident', 'id': i.id, 'to': 'closed'});
        final data = res.data;
        if (res.status >= 400 || (data is Map && data['error'] != null)) {
          final msg = (data is Map ? data['error']?.toString() : null) ?? 'Close failed';
          return _fail(ServerFailure(msg));
        }
        _invalidate(i.id);
        return true;
      });

  Future<bool> _online(Future<bool> Function() op) async {
    if (ref.read(connectivityStatusProvider).valueOrNull == false) {
      return _fail(const NetworkFailure('This action needs an internet connection.'));
    }
    state = const AsyncLoading();
    final ok = await op();
    if (ok) state = const AsyncData(null);
    return ok;
  }

  bool _fail(Failure f) {
    state = AsyncError(f, StackTrace.current);
    return false;
  }

  bool _errBool(Failure f) => _fail(f);

  void _invalidate(String id) {
    ref.invalidate(incidentDetailProvider(id));
    ref.invalidate(incidentListProvider);
  }
}
