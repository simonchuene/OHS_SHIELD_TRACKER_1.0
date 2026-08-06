// path: lib/features/reports/data/report_sharer.dart
import 'package:share_plus/share_plus.dart';

/// Hands an exported report file to the OS share sheet so the user can email it
/// (Gmail/Outlook/…) or send it anywhere else. The file is written locally first
/// by [ReportExporter] — sharing is additive, the local copy always remains.
///
/// `subject` is what mail clients pre-fill as the email subject; `text` becomes
/// the body. Deliberately client-side: the mail goes from the user's own
/// account, so there's no server email provider, no API key, and no report data
/// routed through a third party.
class ReportSharer {
  const ReportSharer();

  Future<ShareResultStatus> shareFile({
    required String filePath,
    required String title,
    required String summary,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: title,
        text: summary,
      ),
    );
    return result.status;
  }
}
