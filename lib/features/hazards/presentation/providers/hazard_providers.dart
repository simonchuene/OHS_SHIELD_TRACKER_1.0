// path: lib/features/hazards/presentation/providers/hazard_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/application/hazard_use_cases.dart';
import 'package:ohs_shield_tracker/features/hazards/data/hazard_repository_impl.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_filter.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/entities/hazard_status.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/repositories/hazard_repository.dart';
import 'package:ohs_shield_tracker/services/notifications/notification_triggers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hazard_providers.g.dart';

@riverpod
HazardRepository hazardRepository(HazardRepositoryRef ref) => HazardRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
HazardUseCases hazardUseCases(HazardUseCasesRef ref) =>
    HazardUseCases(ref.watch(hazardRepositoryProvider));

@riverpod
class HazardFilterController extends _$HazardFilterController {
  @override
  HazardFilter build() => const HazardFilter();
  void update(HazardFilter f) => state = f;
}

@riverpod
Future<List<Hazard>> hazardList(HazardListRef ref) async {
  final filter = ref.watch(hazardFilterControllerProvider);
  final uid = ref.watch(currentUserProvider).valueOrNull?.id;
  final res = await ref.watch(hazardUseCasesProvider).list(filter, uid: uid);
  return res.when(ok: (h) => h, err: (f) => throw f);
}

@riverpod
Future<Hazard> hazardDetail(HazardDetailRef ref, String id) async {
  final res = await ref.watch(hazardUseCasesProvider).get(id);
  return res.when(ok: (h) => h, err: (f) => throw f);
}

/// Reports a hazard using the signed-in user's company/site/department/id.
@riverpod
class HazardReportController extends _$HazardReportController {
  @override
  FutureOr<Hazard?> build() => null;

  Future<Hazard?> submit(ReportHazardParams params) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      state = AsyncError(const AuthFailure('You are signed out.'), StackTrace.current);
      return null;
    }
    state = const AsyncLoading();
    // Default the hazard's home site/department to the reporter's if unset.
    final effective = ReportHazardParams(
      title: params.title,
      category: params.category,
      description: params.description,
      siteId: params.siteId ?? user.siteId,
      departmentId: params.departmentId ?? user.departmentId,
      latitude: params.latitude,
      longitude: params.longitude,
      locationText: params.locationText,
      submitNow: params.submitNow,
    );
    final res = await ref
        .read(hazardUseCasesProvider)
        .report(effective, companyId: user.companyId, reporterId: user.id);
    return res.when(
      ok: (h) {
        state = AsyncData(h);
        ref.invalidate(hazardListProvider);
        ref.read(notificationTriggersProvider).fire(
              NotificationTrigger.hazardCreated,
              entityType: 'hazard', entityId: h.id,
            );
        return h;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return null;
      },
    );
  }
}

/// Resolves the close-guard context (evidence + linked-CAPA state) for a hazard.
@riverpod
Future<HazardGuardContext> hazardGuardContext(HazardGuardContextRef ref, String hazardId) async {
  final client = ref.watch(supabaseClientProvider);
  final evidence = await client
      .from('attachments').select('id')
      .eq('owner_type', 'hazard').eq('owner_id', hazardId).eq('is_active', true).limit(1);
  final openCapas = await client
      .from('corrective_actions').select('id').eq('hazard_id', hazardId).neq('status', 'closed').limit(1);
  return HazardGuardContext(
    hasVerificationEvidence: evidence.isNotEmpty,
    allLinkedCapasClosed: openCapas.isEmpty,
  );
}

/// Drives lifecycle transitions. Non-close steps go through the offline outbox;
/// Close is routed to the authoritative `workflow-transition` Edge Function
/// (online-only, since it performs server-side guard checks).
@riverpod
class HazardWorkflowController extends _$HazardWorkflowController {
  @override
  FutureOr<void> build() {}

  Future<bool> advance(Hazard hazard) async {
    final to = HazardWorkflow.next(hazard.status);
    if (to == null) {
      state = AsyncError(const ValidationFailure('This hazard is already closed.'), StackTrace.current);
      return false;
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    final rank = ref.read(authRoleRankProvider) ?? 0;
    if (user == null) {
      state = AsyncError(const AuthFailure('You are signed out.'), StackTrace.current);
      return false;
    }

    final guard = to == HazardStatus.closed ? await ref.read(hazardGuardContextProvider(hazard.id).future) : null;
    final check = HazardWorkflow.canTransition(from: hazard.status, to: to, roleRank: rank, guard: guard);
    if (!check.allowed) {
      state = AsyncError(ValidationFailure(check.reason ?? 'Transition not allowed.'), StackTrace.current);
      return false;
    }

    state = const AsyncLoading();
    final ok = to == HazardStatus.closed ? await _close(hazard) : await _advanceOffline(hazard, to, user.companyId, user.id);
    if (ok) {
      state = const AsyncData(null);
      ref.invalidate(hazardDetailProvider(hazard.id));
      ref.invalidate(hazardListProvider);
      _fireStageNotification(to, hazard.id);
    }
    return ok;
  }

  Future<bool> _advanceOffline(Hazard h, HazardStatus to, String companyId, String userId) async {
    final res = await ref.read(hazardUseCasesProvider).update(
          id: h.id, changes: {'status': to.dbValue}, baseVersion: h.version,
          companyId: companyId, userId: userId,
        );
    return res.when(ok: (_) => true, err: (f) {
      state = AsyncError(f, StackTrace.current);
      return false;
    },);
  }

  Future<bool> _close(Hazard h) async {
    if (ref.read(connectivityStatusProvider).valueOrNull == false) {
      state = AsyncError(const NetworkFailure('Closing needs a connection (server verification).'), StackTrace.current);
      return false;
    }
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
        'workflow-transition',
        body: {'entityType': 'hazard', 'id': h.id, 'to': 'closed'},
      );
      final data = res.data;
      if (res.status >= 400 || (data is Map && data['error'] != null)) {
        final msg = (data is Map ? data['error']?.toString() : null) ?? 'Close failed';
        state = AsyncError(ServerFailure(msg), StackTrace.current);
        return false;
      }
      return true;
    } catch (e, s) {
      state = AsyncError(ServerFailure('$e'), s);
      return false;
    }
  }

  void _fireStageNotification(HazardStatus to, String id) {
    final trigger = switch (to) {
      HazardStatus.investigation => NotificationTrigger.investigationDue,
      _ => null,
    };
    if (trigger != null) {
      ref.read(notificationTriggersProvider).fire(trigger, entityType: 'hazard', entityId: id);
    }
  }
}
