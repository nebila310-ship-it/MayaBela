import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/report_card_layout.dart';
import 'package:mayabela/services/report_card_pdf_service.dart';
import 'package:mayabela/services/school_mark_service.dart';
import 'package:mayabela/widgets/student_photo_avatar.dart';

/// Official term report card for admin, teachers, parents, and students.
///
/// The subject table lists the subject, score, and grade only. When this
/// school has a logo, stamp, or principal signature, they are drawn on the
/// card: logo in the header, stamp across the lower half of the photo and
/// again at the bottom, signature on the principal line.
class TermReportCardView extends StatefulWidget {
  const TermReportCardView({
    super.key,
    required this.report,
    this.schoolName,
    this.compact = false,
    this.showActions = false,
    this.showSubjectRemarks = true,
    this.logoBytes,
    this.stampBytes,
    this.signatureBytes,
  });

  final StudentGradeReport report;
  final String? schoolName;
  final bool compact;
  final bool showActions;

  /// When false, remarks stay off this card because the screen already
  /// lists a description under each subject.
  final bool showSubjectRemarks;
  final Uint8List? logoBytes;
  final Uint8List? stampBytes;
  final Uint8List? signatureBytes;

  @override
  State<TermReportCardView> createState() => _TermReportCardViewState();
}

class _TermReportCardViewState extends State<TermReportCardView> {
  static const _navy = Color(0xFF1B3A4B);
  static const _gold = Color(0xFFC4A35A);
  static const _paper = Color(0xFFFFFCF7);

  Uint8List? _logo;
  Uint8List? _stamp;
  Uint8List? _signature;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _logo = widget.logoBytes;
    _stamp = widget.stampBytes;
    _signature = widget.signatureBytes;
    if (_logo == null || _stamp == null || _signature == null) {
      _loadMarks();
    }
  }

  @override
  void didUpdateWidget(covariant TermReportCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logoBytes != oldWidget.logoBytes) _logo = widget.logoBytes;
    if (widget.stampBytes != oldWidget.stampBytes) {
      _stamp = widget.stampBytes;
    }
    if (widget.signatureBytes != oldWidget.signatureBytes) {
      _signature = widget.signatureBytes;
    }
    if ((widget.logoBytes == null ||
            widget.stampBytes == null ||
            widget.signatureBytes == null) &&
        widget.report.studentId != oldWidget.report.studentId) {
      _loadMarks();
    }
  }

  Future<void> _loadMarks() async {
    final pdf = ReportCardPdfService.instance;
    final logo = widget.logoBytes ?? await pdf.resolveLogoBytes(null);
    final stamp = widget.stampBytes ??
        await pdf.resolveMarkBytes(null, SchoolMarkKind.stamp);
    final signature = widget.signatureBytes ??
        await pdf.resolveMarkBytes(null, SchoolMarkKind.principalSignature);
    if (!mounted) return;
    setState(() {
      if (logo != null) _logo = logo;
      if (stamp != null) _stamp = stamp;
      if (signature != null) _signature = signature;
    });
  }

  Future<void> _deliver(bool openForPrint) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReportCardPdfService.instance.deliver(
        report: widget.report,
        schoolName: widget.schoolName,
        logoBytes: _logo,
        stampBytes: _stamp,
        signatureBytes: _signature,
        openForPrint: openForPrint,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare the grade report: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final school = ReportCardPdfService.instance.schoolNameFor(widget.schoolName);
    final lines = ReportCardLayout.lines(report);
    final snap = report.attendanceSnapshot;
    final attendance = snap.sessions == 0
        ? '—'
        : '${(snap.rate * 100).round()}%  (${snap.present}P ${snap.late}L ${snap.absent}A)';
    final pad = widget.compact ? 14.0 : 18.0;

    return Container(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _navy, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_logo != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.08,
                    child: Image.memory(
                      _logo!,
                      key: const ValueKey('report-card-watermark'),
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _banner(school, report),
                const SizedBox(height: 12),
                Text(
                  report.studentName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    report.className,
                    report.term,
                    if (report.academicYear != null &&
                        report.academicYear!.trim().isNotEmpty)
                      report.academicYear!.trim(),
                    if (report.studentId != null &&
                        report.studentId!.trim().isNotEmpty)
                      'ID ${report.studentId!.trim()}',
                  ].join('  ·  '),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                if (!report.reportCardPublished) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Draft — not yet published to parents',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _stat('Average', '${report.average.toStringAsFixed(1)}%'),
                    _stat('GPA', report.gpa.toStringAsFixed(2)),
                    _stat('Attendance', attendance),
                  ],
                ),
                const SizedBox(height: 14),
                _subjectTable(lines),
                if (widget.showSubjectRemarks &&
                    lines.any((line) => line.remark != null)) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Subject remarks',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final line in lines)
                    if (line.remark != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.subject,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              line.remark!,
                              key: ValueKey('report-card-remark-${line.subject}'),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
                if (report.homeroomComment?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Homeroom comment',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
                  ),
                  const SizedBox(height: 4),
                  Text(report.homeroomComment!.trim()),
                ],
                if (report.principalComment?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Principal comment',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _navy),
                  ),
                  const SizedBox(height: 4),
                  Text(report.principalComment!.trim()),
                ],
                const SizedBox(height: 18),
                _signatures(),
                if (_stamp != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Image.memory(
                      _stamp!,
                      key: const ValueKey('report-card-bottom-stamp'),
                      height: 84,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ],
                if (widget.showActions) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('report-card-download'),
                        onPressed: _busy ? null : () => _deliver(false),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download PDF'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('report-card-print'),
                        onPressed: _busy ? null : () => _deliver(true),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String school, StudentGradeReport report) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (_logo != null) ...[
            Container(
              key: const ValueKey('report-card-logo'),
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                _logo!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'OFFICIAL GRADE REPORT',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            key: const ValueKey('report-card-photo'),
            width: 64,
            height: 78,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _gold, width: 1.6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: StudentPhotoAvatar(
                      studentId: report.studentId,
                      name: report.studentName,
                      radius: 30,
                      fallbackColor: _navy,
                      enableViewer: false,
                    ),
                  ),
                ),
                if (_stamp != null)
                  Positioned(
                    key: const ValueKey('report-card-photo-stamp'),
                    left: 4,
                    right: 2,
                    bottom: 2,
                    height: 38,
                    child: Image.memory(
                      _stamp!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
          ),
        ],
      ),
    );
  }

  Widget _subjectTable(List<ReportCardSubjectLine> lines) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1.3),
        2: FlexColumnWidth(0.7),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: Color(0xFFE4E7EB)),
      ),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: _navy),
          children: [
            _Head('Subject'),
            _Head('Score', align: TextAlign.right),
            _Head('Grade', align: TextAlign.center),
          ],
        ),
        for (var i = 0; i < lines.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFFF7F5F0) : Colors.white.withValues(alpha: 0.72),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  lines[i].subject,
                  key: ValueKey('report-card-subject-${lines[i].subject}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  lines[i].scoreLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  lines[i].grade,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _signatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SignLine(role: 'Homeroom teacher')),
            const SizedBox(width: 18),
            Expanded(
              child: _SignLine(
                role: 'Principal',
                lineKey: const ValueKey('report-card-principal-sign'),
                imageBytes: _signature,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Date',
              style: TextStyle(fontWeight: FontWeight.w800, color: _navy, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Container(
              width: 140,
              height: 18,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _navy, width: 0.8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SignLine extends StatelessWidget {
  const _SignLine({required this.role, this.lineKey, this.imageBytes});

  final String role;
  final Key? lineKey;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: lineKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          width: double.infinity,
          child: imageBytes == null
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Image.memory(
                    imageBytes!,
                    key: const ValueKey('report-card-principal-signature'),
                    height: 34,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
        ),
        Container(
          height: 1,
          color: const Color(0xFF1B3A4B),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B3A4B),
            fontSize: 12,
          ),
        ),
        Text(
          'Signature',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
