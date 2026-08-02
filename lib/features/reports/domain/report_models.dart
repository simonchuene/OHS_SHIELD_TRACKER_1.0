// path: lib/features/reports/domain/report_models.dart
/// MVP1 report catalogue. MVP2/MVP3 reporting is explicitly out of scope.
enum ReportType {
  hazardRegister('Hazard Register'),
  incidentLog('Incident Log'),
  capaStatus('CAPA Status'),
  inspectionSummary('Inspection Summary'),
  riskRegister('Risk Register');

  const ReportType(this.title);
  final String title;
}

enum ReportFormat { csv, pdf }

/// Optional filters (RBAC row-scoping is handled by RLS, like the dashboards).
class ReportFilters {
  const ReportFilters({this.from, this.to});
  final DateTime? from;
  final DateTime? to;

  bool matches(DateTime? d) {
    if (d == null) return true;
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }
}

/// A generated, tabular report (the shape both CSV and PDF render from).
class ReportResult {
  const ReportResult({
    required this.type,
    required this.title,
    required this.columns,
    required this.rows,
    required this.generatedAt,
  });

  final ReportType type;
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final DateTime generatedAt;

  int get rowCount => rows.length;
}

/// A previously generated report file (local history / offline access).
class ReportHistoryItem {
  const ReportHistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.format,
    required this.filePath,
    required this.generatedAt,
  });

  final String id;
  final ReportType type;
  final String title;
  final ReportFormat format;
  final String filePath;
  final DateTime generatedAt;
}
