// path: lib/features/inspections/presentation/providers/inspection_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/capa/presentation/providers/capa_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/features/inspections/application/inspection_use_cases.dart';
import 'package:ohs_shield_tracker/features/inspections/data/inspection_repository_impl.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/entities/inspection_enums.dart';
import 'package:ohs_shield_tracker/features/inspections/domain/repositories/inspection_repository.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inspection_providers.g.dart';

@riverpod
InspectionRepository inspectionRepository(InspectionRepositoryRef ref) => InspectionRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
InspectionUseCases inspectionUseCases(InspectionUseCasesRef ref) =>
    InspectionUseCases(ref.watch(inspectionRepositoryProvider));

@riverpod
Future<List<Inspection>> inspectionsList(InspectionsListRef ref) async {
  final res = await ref.watch(inspectionUseCasesProvider).list();
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
Future<Inspection> inspectionDetail(InspectionDetailRef ref, String id) async {
  final res = await ref.watch(inspectionUseCasesProvider).get(id);
  return res.when(ok: (i) => i, err: (f) => throw f);
}

@riverpod
class InspectionController extends _$InspectionController {
  @override
  FutureOr<void> build() {}

  Future<Inspection?> create(InspectionType type) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) { _fail(const AuthFailure('You are signed out.')); return null; }
    state = const AsyncLoading();
    final res = await ref.read(inspectionUseCasesProvider).create(
      type: type, companyId: user.companyId, inspectorId: user.id, siteId: user.siteId, departmentId: user.departmentId,
    );
    return res.when(ok: (i) { state = const AsyncData(null); ref.invalidate(inspectionsListProvider); return i; }, err: (f) { _fail(f); return null; });
  }

  Future<bool> setItemResult(Inspection inspection, String itemId, InspectionItemResult result, int baseVersion, {String? notes}) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return _fail(const AuthFailure('You are signed out.'));
    final res = await ref.read(inspectionUseCasesProvider).setItemResult(
        itemId: itemId, result: result, notes: notes, baseVersion: baseVersion, companyId: user.companyId, userId: user.id,);
    return res.when(ok: (_) { ref.invalidate(inspectionDetailProvider(inspection.id)); return true; }, err: _errBool);
  }

  Future<bool> submit(Inspection inspection) async {
    if (ref.read(connectivityStatusProvider).valueOrNull == false) {
      return _fail(const NetworkFailure('Submitting needs a connection (auto-creates hazards/CAPAs on the server).'));
    }
    state = const AsyncLoading();
    final res = await ref.read(inspectionUseCasesProvider).submit(inspection);
    return res.when(ok: (_) {
      state = const AsyncData(null);
      ref.invalidate(inspectionDetailProvider(inspection.id));
      ref.invalidate(inspectionsListProvider);
      ref.invalidate(hazardListProvider); // failed items may have created hazards
      ref.invalidate(capaListProvider);
      return true;
    }, err: _errBool,);
  }

  bool _fail(Failure f) { state = AsyncError(f, StackTrace.current); return false; }
  bool _errBool(Failure f) => _fail(f);
}
