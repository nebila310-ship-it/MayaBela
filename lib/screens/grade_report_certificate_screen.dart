import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/grade_report_certificate_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/grade_report_certificate_view.dart';

Future<void> openGradeReportCertificate(
  BuildContext context,
  StudentGradeReport report,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GradeReportCertificateScreen(report: report),
    ),
  );
}

class GradeReportCertificateScreen extends StatefulWidget {
  const GradeReportCertificateScreen({super.key, required this.report});

  final StudentGradeReport report;

  @override
  State<GradeReportCertificateScreen> createState() =>
      _GradeReportCertificateScreenState();
}

class _GradeReportCertificateScreenState
    extends State<GradeReportCertificateScreen> {
  late final GradeReportCertificateSnapshot _certificate =
      GradeReportCertificateService.instance.buildSnapshot(widget.report);
  bool _busy = false;

  Future<void> _download() async {
    final s = AppLocale.instance.strings;
    setState(() => _busy = true);
    try {
      await GradeReportCertificateService.instance.downloadPdf(_certificate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.gradeReportCertificateReady)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.gradeReportCertificateFailed),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF312E81),
            foregroundColor: Colors.white,
            title: Text(s.gradeReportCertificateTitle),
            actions: [
              TextButton.icon(
                onPressed: _busy ? null : _download,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_outlined, color: Colors.white),
                label: Text(
                  s.downloadGradeReportCertificate,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              GradeReportCertificateView(certificate: _certificate),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _download,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(s.downloadGradeReportCertificate),
              ),
            ],
          ),
        );
      },
    );
  }
}
