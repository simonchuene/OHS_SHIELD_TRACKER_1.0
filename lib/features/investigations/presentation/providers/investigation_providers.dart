// path: lib/features/investigations/presentation/providers/investigation_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/domain/hazard_workflow.dart' show TransitionCheck;
import 'package:ohs_shield_tracker/features/investigations/application/investigation_use_cases.dart';
import 'package:ohs_shield_tracker/features/investigations/data/investigation_repository_impl.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/entities/investigation_enums.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/investigation_workflow.dart';
import 'package:ohs_shield_tracker/features/investigations/domain/repositories/investigation_repository.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'investigation_providers.g.dart';

@riverpod
InvestigationRepository investigationRepository(InvestigationRepositoryRef ref) => InvestigationRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
InvestigationUseCases investigationUseCases(InvestigationUseCasesRef ref) =>
    InvestigationUseCases(ref.watch(investigationRepositoryProvider));

@riverpod
Future<List<Investigation>> investigationsAll(InvestigationsAllRef ref) async {
  final res = await ref.watch(investigationUseCasesProvider).list();
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
Future<List<Investigation>> investigationsForHazard(InvestigationsForHazardRef ref, String hazardId) async {
  final res = await ref.watch(investigationUseCasesProvider).list(hazardId: hazardId);
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
Future<Investigation> investigationDetail(InvestigationDetailRef ref, String id) async {
  final res = await ref.watch(investigationUseCasesProvider).get(id);
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
class InvestigationController extends _$InvestigationController {
  @override
  FutureOr<void> build() {}

  Future<bool> saveDetails(Investigation inv, Map<String, dynamic> changes) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return _fail(const AuthFailure('You are signed out.'));
    state = const AsyncLoading();
    final res = await ref.read(investigationUseCasesProvider).update(
        id: inv.id, changes: changes, baseVersion: inv.version, companyId: user.companyId, userId: user.id,);
    return res.when(ok: (_) { state = const AsyncData(null); _invalidate(inv.id); return true; }, err: _errBool);
  }

  /// Advance to [to]; validates the workflow (complete requires root cause +
  /// recommendations). Uses the offline outbox.
  Future<bool> advance(Investigation inv, InvestigationStatus to) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final rank = ref.read(authRoleRankProvider) ?? 0;
    if (user == null) return _fail(const AuthFailure('You are signed out.'));
    final TransitionCheck check = InvestigationWorkflow.canTransition(investigation: inv, to: to, roleRank: rank);
    if (!check.allowed) return _fail(ValidationFailure(check.reason ?? 'Transition not allowed.'));

    final changes = <String, dynamic>{
      'status': to.dbValue,
      if (to == InvestigationStatus.completed) 'completed_at': DateTime.now().toIso8601String(),
    };
    return saveDetails(inv, changes);
  }

  Future<bool> generateCapa(Investigation inv, String description, String priority) async {
    if (ref.read(connectivityStatusProvider).valueOrNull == false) {
      return _fail(const NetworkFailure('Creating a CAPA needs an internet connection.'));
    }
    final user = ref.read(currentUserProvider).valueOrNull!;
    state = const AsyncLoading();
    final res = await ref.read(investigationUseCasesProvider)
        .generateCapa(inv.id, user.companyId, description, priority, siteId: inv.siteId);
    return res.when(ok: (_) { state = const AsyncData(null); _invalidate(inv.id); return true; }, err: _errBool);
  }

  bool _fail(Failure f) { state = AsyncError(f, StackTrace.current); return false; }
  bool _errBool(Failure f) => _fail(f);
  void _invalidate(String id) {
    ref.invalidate(investigationDetailProvider(id));
    ref.invalidate(investigationsAllProvider);
  }
}
