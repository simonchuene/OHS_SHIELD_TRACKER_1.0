// path: lib/features/capa/presentation/providers/capa_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/capa/application/capa_use_cases.dart';
import 'package:ohs_shield_tracker/features/capa/data/capa_repository_impl.dart';
import 'package:ohs_shield_tracker/features/capa/domain/capa_workflow.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/capa_enums.dart';
import 'package:ohs_shield_tracker/features/capa/domain/entities/corrective_action.dart';
import 'package:ohs_shield_tracker/features/capa/domain/repositories/capa_repository.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;
import 'package:ohs_shield_tracker/services/notifications/notification_triggers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'capa_providers.g.dart';

typedef NamedUser = ({String id, String name});

@riverpod
CapaRepository capaRepository(CapaRepositoryRef ref) => CapaRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
CapaUseCases capaUseCases(CapaUseCasesRef ref) => CapaUseCases(ref.watch(capaRepositoryProvider));

@riverpod
class CapaFilterController extends _$CapaFilterController {
  @override
  CapaFilter build() => const CapaFilter();
  void update(CapaFilter f) => state = f;
}

@riverpod
Future<List<CorrectiveAction>> capaList(CapaListRef ref) async {
  final filter = ref.watch(capaFilterControllerProvider);
  final uid = ref.watch(currentUserProvider).valueOrNull?.id;
  final res = await ref.watch(capaUseCasesProvider).list(filter, uid: uid);
  return res.when(ok: (c) => c, err: (f) => throw f);
}

@riverpod
Future<CorrectiveAction> capaDetail(CapaDetailRef ref, String id) async {
  final res = await ref.watch(capaUseCasesProvider).get(id);
  return res.when(ok: (c) => c, err: (f) => throw f);
}

/// CAPAs linked to a hazard — drives the hazard detail's corrective-actions list.
@riverpod
Future<List<CorrectiveAction>> capasForHazard(CapasForHazardRef ref, String hazardId) async {
  final res = await ref.watch(capaUseCasesProvider).listForHazard(hazardId);
  return res.when(ok: (c) => c, err: (f) => throw f);
}

/// Company users for the owner picker (RLS: user_profiles readable within company).
@riverpod
Future<List<NamedUser>> companyUsers(CompanyUsersRef ref) async {
  final rows = await ref.watch(supabaseClientProvider)
      .from('user_profiles').select('user_id, first_name, last_name').order('first_name');
  return [for (final r in rows) (id: r['user_id'] as String, name: '${r['first_name']} ${r['last_name']}'.trim())];
}

@riverpod
class CapaController extends _$CapaController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<CorrectiveAction?> create({
    required String description,
    required CapaPriority priority,
    required CapaSourceRef source,
    String? ownerId,
    DateTime? dueDate,
    String? siteId,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) { _fail(const AuthFailure('You are signed out.')); return null; }
    state = const AsyncLoading();
    final res = await ref.read(capaUseCasesProvider).create(
      companyId: user.companyId, description: description, priority: priority, source: source,
      siteId: siteId, ownerId: ownerId, dueDate: dueDate, userId: user.id,
    );
    return res.when(ok: (c) {
      state = const AsyncData(null);
      ref.invalidate(capaListProvider);
      if (ownerId != null) {
        // Send the owner explicitly. A CAPA is created into the offline outbox
        // with a client-minted id, so it does not exist server-side yet — the
        // function's `owner_id` lookup would miss and fall through to the
        // Safety Officer+ audience, notifying the wrong people and never the
        // owner. `recipientIds` is honoured ahead of any lookup.
        ref.read(notificationTriggersProvider).fire(
            NotificationTrigger.capaAssigned, entityType: 'corrective_action', entityId: c.id,
            data: {'recipientIds': [ownerId]},);
      }
      return c;
    }, err: (f) { _fail(f); return null; },);
  }

  Future<bool> patch(CorrectiveAction capa, Map<String, dynamic> changes) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return _fail(const AuthFailure('You are signed out.'));
    state = const AsyncLoading();
    final res = await ref.read(capaUseCasesProvider).update(
        id: capa.id, changes: changes, baseVersion: capa.version, companyId: user.companyId, userId: user.id,);
    return res.when(ok: (_) {
      state = const AsyncData(null);
      _invalidate(capa.id);
      // Reassignment must notify the new owner too — `create` only covers the
      // first assignment, so changing owner_id here previously notified nobody.
      final newOwnerId = changes['owner_id'] as String?;
      if (newOwnerId != null && newOwnerId != capa.ownerId) {
        ref.read(notificationTriggersProvider).fire(
            NotificationTrigger.capaAssigned, entityType: 'corrective_action', entityId: capa.id,
            data: {'recipientIds': [newOwnerId]},);
      }
      return true;
    }, err: _errBool,);
  }

  /// [completionNotes] is written alongside the status when the owner submits
  /// for verification — the record of what was actually done. Ignored for other
  /// transitions, which have their own evidence (verification_notes on close).
  Future<bool> advance(CorrectiveAction capa, CapaStatus to, {String? completionNotes}) async {
    final rank = ref.read(authRoleRankProvider) ?? 0;
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    final hasEvidence = to == CapaStatus.closed ? await _hasEvidence(capa.id) : false;
    final TransitionCheck check = CapaWorkflow.canTransition(
      from: capa.status, to: to, roleRank: rank,
      guard: CapaGuardContext(
        hasOwner: capa.hasOwner,
        hasVerificationEvidence: hasEvidence,
        isOwner: userId != null && capa.ownerId == userId,
      ),
    );
    if (!check.allowed) return _fail(ValidationFailure(check.reason ?? 'Transition not allowed.'));

    if (to == CapaStatus.closed && ref.read(connectivityStatusProvider).valueOrNull == false) {
      return _fail(const NetworkFailure('Closing needs a connection to verify evidence.'));
    }
    final user = ref.read(currentUserProvider).valueOrNull!;
    final notes = completionNotes?.trim();
    final changes = <String, dynamic>{
      'status': to.dbValue,
      if (to == CapaStatus.verification && notes != null && notes.isNotEmpty) 'completion_notes': notes,
      if (to == CapaStatus.closed) ...{'closed_at': DateTime.now().toIso8601String(), 'verified_by': user.id, 'verified_at': DateTime.now().toIso8601String()},
    };
    final ok = await patch(capa, changes);
    // Handing work back is the one step with no signal to the people who must
    // act on it: without this the CAPA sits in Verification until a Safety
    // Officer happens to look. No recipientIds — the default Safety Officer+
    // audience is exactly right, and §16's actor filter keeps the submitting
    // owner from notifying themselves.
    if (ok && to == CapaStatus.verification) {
      ref.read(notificationTriggersProvider).fire(
            NotificationTrigger.capaVerificationDue,
            entityType: 'corrective_action',
            entityId: capa.id,
          );
    }
    return ok;
  }

  Future<bool> _hasEvidence(String capaId) async {
    try {
      final rows = await ref.read(supabaseClientProvider)
          .from('attachments').select('id').eq('owner_type', 'corrective_action').eq('owner_id', capaId).eq('is_active', true).limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _fail(Failure f) { state = AsyncError(f, StackTrace.current); return false; }
  bool _errBool(Failure f) => _fail(f);
  void _invalidate(String id) { ref.invalidate(capaDetailProvider(id)); ref.invalidate(capaListProvider); }
}
