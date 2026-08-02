// path: lib/features/risk/presentation/providers/risk_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:ohs_shield_tracker/features/hazards/presentation/providers/hazard_providers.dart';
import 'package:ohs_shield_tracker/features/risk/application/risk_use_cases.dart';
import 'package:ohs_shield_tracker/features/risk/data/risk_assessment_repository_impl.dart';
import 'package:ohs_shield_tracker/features/risk/domain/entities/risk_assessment.dart';
import 'package:ohs_shield_tracker/features/risk/domain/repositories/risk_assessment_repository.dart';
import 'package:ohs_shield_tracker/services/notifications/notification_triggers.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'risk_providers.g.dart';

@riverpod
RiskAssessmentRepository riskRepository(RiskRepositoryRef ref) => RiskAssessmentRepositoryImpl(
      ref.watch(supabaseClientProvider),
      ref.watch(offlineMutationServiceProvider),
      ref.watch(appDatabaseProvider),
      ref.watch(loggerProvider),
    );

@riverpod
RiskUseCases riskUseCases(RiskUseCasesRef ref) => RiskUseCases(ref.watch(riskRepositoryProvider));

@riverpod
Future<RiskAssessment?> latestRisk(LatestRiskRef ref, String hazardId) async {
  final res = await ref.watch(riskUseCasesProvider).latestForHazard(hazardId);
  return res.when(ok: (a) => a, err: (f) => throw f);
}

/// Live calculator state (Likelihood/Severity + optional residual).
class RiskCalcState {
  const RiskCalcState({this.likelihood = 1, this.severity = 1, this.residualLikelihood, this.residualSeverity});
  final int likelihood;
  final int severity;
  final int? residualLikelihood;
  final int? residualSeverity;

  RiskCalcState copyWith({int? likelihood, int? severity, int? residualLikelihood, int? residualSeverity, bool clearResidual = false}) =>
      RiskCalcState(
        likelihood: likelihood ?? this.likelihood,
        severity: severity ?? this.severity,
        residualLikelihood: clearResidual ? null : (residualLikelihood ?? this.residualLikelihood),
        residualSeverity: clearResidual ? null : (residualSeverity ?? this.residualSeverity),
      );
}

@riverpod
class RiskCalculatorController extends _$RiskCalculatorController {
  @override
  RiskCalcState build() => const RiskCalcState();
  void setLikelihood(int v) => state = state.copyWith(likelihood: v);
  void setSeverity(int v) => state = state.copyWith(severity: v);
  void setResidualLikelihood(int v) => state = state.copyWith(residualLikelihood: v);
  void setResidualSeverity(int v) => state = state.copyWith(residualSeverity: v);
  void clearResidual() => state = state.copyWith(clearResidual: true);
}

@riverpod
class SaveRiskController extends _$SaveRiskController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(SaveRiskParams params) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      state = AsyncError(const AuthFailure('You are signed out.'), StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    final res = await ref.read(riskUseCasesProvider).save(params, companyId: user.companyId, assessorId: user.id);
    return res.when(
      ok: (a) {
        state = const AsyncData(null);
        ref.invalidate(latestRiskProvider(params.hazardId));
        ref.invalidate(hazardDetailProvider(params.hazardId));
        ref.invalidate(hazardListProvider);
        ref.read(notificationTriggersProvider).fire(NotificationTrigger.riskAssessed, entityType: 'hazard', entityId: params.hazardId);
        return true;
      },
      err: (f) {
        state = AsyncError(f, StackTrace.current);
        return false;
      },
    );
  }
}
