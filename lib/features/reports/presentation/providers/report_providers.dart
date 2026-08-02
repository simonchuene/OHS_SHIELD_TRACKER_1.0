// path: lib/features/reports/presentation/providers/report_providers.dart
import 'dart:async';

import 'package:ohs_shield_tracker/core/providers/core_providers.dart';
import 'package:ohs_shield_tracker/features/reports/data/report_exporter.dart';
import 'package:ohs_shield_tracker/features/reports/data/report_repository.dart';
import 'package:ohs_shield_tracker/features/reports/domain/report_models.dart';
import 'package:ohs_shield_tracker/services/sync/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_providers.g.dart';

@riverpod
ReportRepository reportRepository(ReportRepositoryRef ref) => ReportRepository(
      ref.watch(supabaseClientProvider),
      ref.watch(appDatabaseProvider),
      ReportExporter(),
      ref.watch(loggerProvider),
    );

@riverpod
Future<List<ReportHistoryItem>> reportHistory(ReportHistoryRef ref) =>
    ref.watch(reportRepositoryProvider).history();

/// Holds the most recently generated report (for preview + export).
@riverpod
class ReportController extends _$ReportController {
  @override
  FutureOr<ReportResult?> build() => null;

  Future<void> generate(ReportType type, ReportFilters filters) async {
    state = const AsyncLoading();
    final res = await ref.read(reportRepositoryProvider).generate(type, filters);
    state = res.when(ok: (r) => AsyncData(r), err: (f) => AsyncError(f, StackTrace.current));
  }

  /// Exports the current result; returns the saved file path (or null on failure).
  Future<String?> export(ReportFormat format) async {
    final result = state.valueOrNull;
    if (result == null) return null;
    final res = await ref.read(reportRepositoryProvider).export(result, format);
    return res.when(
      ok: (item) {
        ref.invalidate(reportHistoryProvider);
        return item.filePath;
      },
      err: (_) => null,
    );
  }
}
