// path: lib/features/reports/data/report_repository.dart
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/core/database/app_database.dart';
import 'package:ohs_shield_tracker/core/error/failure.dart';
import 'package:ohs_shield_tracker/core/error/result.dart';
import 'package:ohs_shield_tracker/core/logging/logger_service.dart';
import 'package:ohs_shield_tracker/features/reports/data/report_exporter.dart';
import 'package:ohs_shield_tracker/features/reports/domain/report_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Generates MVP1 reports from RLS-scoped queries (so a report shows exactly the
/// rows the caller may see — same scoping as the dashboards). Exports to CSV/PDF
/// and records local history (offline-openable).
class ReportRepository {
  ReportRepository(this._client, this._db, this._exporter, this._logger, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final SupabaseClient _client;
  final AppDatabase _db;
  final ReportExporter _exporter;
  final LoggerService _logger;
  final Uuid _uuid;

  static final _date = DateFormat.yMMMd();

  Future<Result<ReportResult>> generate(ReportType type, ReportFilters filters) async {
    try {
      final now = DateTime.now();
      final (columns, rows) = switch (type) {
        ReportType.hazardRegister => await _hazards(filters),
        ReportType.incidentLog => await _incidents(filters),
        ReportType.capaStatus => await _capas(filters),
        ReportType.inspectionSummary => await _inspections(filters),
        ReportType.riskRegister => await _risks(filters),
      };
      return Ok(ReportResult(type: type, title: type.title, columns: columns, rows: rows, generatedAt: now));
    } catch (e, s) {
      _logger.warn('report generate failed (likely offline)', e, s);
      return Err(const NetworkFailure('Generating a report needs a connection. Past reports are available below.'));
    }
  }

  Future<Result<ReportHistoryItem>> export(ReportResult result, ReportFormat format) async {
    try {
      final path = format == ReportFormat.csv ? await _exporter.exportCsv(result) : await _exporter.exportPdf(result);
      final id = _uuid.v4();
      await _db.insertReport(ReportHistoryEntriesCompanion(
        id: Value(id), reportType: Value(result.type.name), title: Value(result.title),
        format: Value(format.name), filePath: Value(path), generatedAt: Value(result.generatedAt),
      ),);
      return Ok(ReportHistoryItem(id: id, type: result.type, title: result.title, format: format, filePath: path, generatedAt: result.generatedAt));
    } catch (e, s) {
      _logger.error('report export failed', e, s);
      return const Err(UnknownFailure());
    }
  }

  Future<List<ReportHistoryItem>> history() async {
    final rows = await _db.listReports();
    return [
      for (final r in rows)
        ReportHistoryItem(
          id: r.id,
          type: ReportType.values.firstWhere((t) => t.name == r.reportType, orElse: () => ReportType.hazardRegister),
          title: r.title,
          format: r.format == 'pdf' ? ReportFormat.pdf : ReportFormat.csv,
          filePath: r.filePath,
          generatedAt: r.generatedAt,
        ),
    ];
  }

  String _d(String? iso) => iso == null ? '-' : _date.format(DateTime.parse(iso));

  Future<(List<String>, List<List<String>>)> _hazards(ReportFilters f) async {
    final data = await _client.from('hazards').select('reference,title,category,status,risk_level,reported_at').order('reported_at', ascending: false);
    final rows = <List<String>>[];
    for (final r in data) {
      if (!f.matches(DateTime.tryParse(r['reported_at'] as String? ?? ''))) continue;
      rows.add([r['reference']?.toString() ?? '-', r['title'].toString(), r['category'].toString(), r['status'].toString(), r['risk_level']?.toString() ?? '-', _d(r['reported_at'] as String?)]);
    }
    return (['Reference', 'Title', 'Category', 'Status', 'Risk', 'Reported'], rows);
  }

  Future<(List<String>, List<List<String>>)> _incidents(ReportFilters f) async {
    final data = await _client.from('incidents').select('incident_type,severity,status,occurred_at,location_text').order('occurred_at', ascending: false);
    final rows = <List<String>>[];
    for (final r in data) {
      if (!f.matches(DateTime.tryParse(r['occurred_at'] as String? ?? ''))) continue;
      rows.add([r['incident_type'].toString(), r['severity'].toString(), r['status'].toString(), _d(r['occurred_at'] as String?), r['location_text']?.toString() ?? '-']);
    }
    return (['Type', 'Severity', 'Status', 'Occurred', 'Location'], rows);
  }

  Future<(List<String>, List<List<String>>)> _capas(ReportFilters f) async {
    final data = await _client.from('corrective_actions').select('description,priority,status,due_date').order('created_at', ascending: false);
    final rows = [for (final r in data) [r['description'].toString(), r['priority'].toString(), r['status'].toString(), _d(r['due_date'] as String?)]];
    return (['Description', 'Priority', 'Status', 'Due'], rows);
  }

  Future<(List<String>, List<List<String>>)> _inspections(ReportFilters f) async {
    final data = await _client.from('inspections').select('inspection_type,status,score,conducted_at').order('conducted_at', ascending: false);
    final rows = <List<String>>[];
    for (final r in data) {
      if (!f.matches(DateTime.tryParse(r['conducted_at'] as String? ?? ''))) continue;
      rows.add([r['inspection_type'].toString(), r['status'].toString(), r['score'] != null ? '${r['score']}%' : '-', _d(r['conducted_at'] as String?)]);
    }
    return (['Type', 'Status', 'Score', 'Conducted'], rows);
  }

  Future<(List<String>, List<List<String>>)> _risks(ReportFilters f) async {
    final data = await _client.from('risk_assessments').select('likelihood,severity,risk_score,risk_band,assessed_at, hazards(title)').order('assessed_at', ascending: false);
    final rows = <List<String>>[];
    for (final r in data) {
      if (!f.matches(DateTime.tryParse(r['assessed_at'] as String? ?? ''))) continue;
      final title = (r['hazards'] as Map?)?['title']?.toString() ?? '-';
      rows.add([title, r['likelihood'].toString(), r['severity'].toString(), r['risk_score'].toString(), r['risk_band'].toString(), _d(r['assessed_at'] as String?)]);
    }
    return (['Hazard', 'Likelihood', 'Severity', 'Score', 'Band', 'Assessed'], rows);
  }
}
