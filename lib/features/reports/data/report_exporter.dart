// path: lib/features/reports/data/report_exporter.dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ohs_shield_tracker/features/reports/domain/report_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Pure CSV serialisation (RFC-4180-ish escaping) — testable without I/O.
abstract final class ReportCsv {
  static String build(ReportResult r) {
    final sb = StringBuffer()..writeln(_row(r.columns));
    for (final row in r.rows) {
      sb.writeln(_row(row));
    }
    return sb.toString();
  }

  static String _row(List<String> cells) => cells.map(_escape).join(',');

  static String _escape(String v) {
    final s = v.replaceAll('"', '""');
    return (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"$s"' : s;
  }
}

/// Writes reports to `documents/reports/` and returns the file path. (Opening /
/// sharing the file is an OS concern — wire share_plus/open_filex at integration.)
class ReportExporter {
  Future<String> exportCsv(ReportResult r) async {
    final file = await _file(r, 'csv');
    await file.writeAsString(ReportCsv.build(r));
    return file.path;
  }

  Future<String> exportPdf(ReportResult r) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: r.title),
          pw.Text('Generated ${DateFormat.yMMMd().add_jm().format(r.generatedAt)} · ${r.rowCount} row(s)',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: r.columns,
            data: r.rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
            headerCellDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
          ),
        ],
      ),
    );
    final file = await _file(r, 'pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  Future<File> _file(ReportResult r, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final reports = Directory(p.join(dir.path, 'reports'))..createSync(recursive: true);
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(r.generatedAt);
    final name = '${r.type.name}_$stamp.$ext';
    return File(p.join(reports.path, name));
  }
}
