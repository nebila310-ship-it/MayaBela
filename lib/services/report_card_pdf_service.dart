import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/school_logo_style.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/report_card_layout.dart';
import 'package:mayabela/services/school_logo_service.dart';
import 'package:mayabela/services/school_mark_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/web_file_utils.dart';

/// Official grade-report PDF: school logo, student photo, stamp, and signature.
///
/// When this school has saved a stamp, it covers the lower half of the photo
/// and is repeated at the bottom of the card. A saved principal signature is
/// drawn on the principal line. Missing assets are left blank.
class ReportCardPdfService {
  ReportCardPdfService._();
  static final instance = ReportCardPdfService._();

  static const _navy = PdfColor.fromInt(0xFF1B3A4B);
  static const _gold = PdfColor.fromInt(0xFFC4A35A);
  static const _ink = PdfColor.fromInt(0xFF1F2933);
  static const _muted = PdfColor.fromInt(0xFF5C6B73);

  String schoolNameFor(String? override) {
    final given = override?.trim();
    if (given != null && given.isNotEmpty) return given;
    final id = AuthService.activeSchoolId;
    final name = SchoolRegistryService.instance.lookup(id)?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'School';
  }

  String fileNameFor(StudentGradeReport report) {
    final who = ReportCardLayout.fileToken(
      report.studentId?.trim().isNotEmpty == true
          ? report.studentId!
          : report.studentName,
    );
    final term = ReportCardLayout.fileToken(report.term);
    return 'grade_report_${who}_$term.pdf';
  }

  Future<Uint8List?> resolveLogoBytes(String? schoolId) async {
    final id = (schoolId ?? AuthService.activeSchoolId ?? '').trim();
    if (id.isEmpty) return null;
    final style =
        SchoolRegistryService.instance.lookup(id)?.logoStyle ??
        SchoolLogoStyle.rectangular;
    final cached = WebAttachmentCache.instance.read(
      SchoolLogoService.cacheKey(id, style),
    );
    if (_decodes(cached)) return cached;
    final remote = await SchoolLogoService.instance.downloadBrandingBytes(
      schoolId: id,
      style: style,
    );
    if (_decodes(remote)) return remote;
    return null;
  }

  Future<Uint8List?> resolveMarkBytes(
    String? schoolId,
    SchoolMarkKind kind,
  ) async {
    final id = (schoolId ?? AuthService.activeSchoolId ?? '').trim();
    if (id.isEmpty) return null;
    final school = SchoolRegistryService.instance.lookup(id);
    final bytes = await SchoolMarkService.instance.resolve(
      schoolId: id,
      kind: kind,
      storedUrl: kind == SchoolMarkKind.stamp
          ? school?.stampUrl
          : school?.principalSignatureUrl,
      storedPath: kind == SchoolMarkKind.stamp
          ? school?.stampPath
          : school?.principalSignaturePath,
    );
    if (_decodes(bytes)) return bytes;
    return null;
  }

  Future<Uint8List?> resolvePhotoBytes(StudentGradeReport report) async {
    final record = StudentRegistryService.instance.resolveForPhoto(
      studentId: report.studentId,
      name: report.studentName,
    );
    final id = record?.studentId ?? report.studentId;
    final path = record?.photoPath;
    final cached = StudentPhotoService.instance.lookupBytes(
      id,
      storedPath: path,
    );
    if (_decodes(cached)) return cached;
    final hydrated = await StudentPhotoService.instance.hydrateBytes(
      id,
      storedPath: path,
    );
    if (_decodes(hydrated)) return hydrated;
    return null;
  }

  bool _decodes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return false;
    try {
      return img.decodeImage(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> buildBytes({
    required StudentGradeReport report,
    String? schoolName,
    Uint8List? logoBytes,
    Uint8List? photoBytes,
    Uint8List? stampBytes,
    Uint8List? signatureBytes,
  }) async {
    final school = schoolNameFor(schoolName);
    final lines = ReportCardLayout.lines(report);
    final logo = _decodes(logoBytes) ? pw.MemoryImage(logoBytes!) : null;
    final photo = _decodes(photoBytes) ? pw.MemoryImage(photoBytes!) : null;
    final stamp = _decodes(stampBytes) ? pw.MemoryImage(stampBytes!) : null;
    final signature =
        _decodes(signatureBytes) ? pw.MemoryImage(signatureBytes!) : null;
    final snap = report.attendanceSnapshot;
    final attendance = snap.sessions == 0
        ? '-'
        : '${(snap.rate * 100).round()}%  (${snap.present} present, ${snap.late} late, ${snap.absent} absent)';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 40),
          buildBackground: (context) {
            if (logo == null) return pw.SizedBox();
            return pw.Center(
              child: pw.Opacity(
                opacity: 0.08,
                child: pw.Image(logo, width: 280, height: 280),
              ),
            );
          },
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                school,
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ),
        build: (context) => [
          _header(
            school: school,
            logo: logo,
            photo: photo,
            stamp: stamp,
            studentName: report.studentName,
          ),
          pw.SizedBox(height: 14),
          _identity(report),
          pw.SizedBox(height: 12),
          _stats(report, attendance),
          pw.SizedBox(height: 16),
          _subjectTable(lines),
          if (lines.any((line) => line.remark != null)) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Subject remarks',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(height: 6),
            for (final line in lines)
              if (line.remark != null) ...[
                pw.Text(
                  line.subject,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                pw.Text(
                  line.remark!,
                  style: const pw.TextStyle(fontSize: 9, color: _ink),
                ),
                pw.SizedBox(height: 6),
              ],
          ],
          if (report.homeroomComment?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Homeroom comment',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              report.homeroomComment!.trim(),
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
          ],
          if (report.principalComment?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Principal comment',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              report.principalComment!.trim(),
              style: const pw.TextStyle(fontSize: 10, color: _ink),
            ),
          ],
          pw.SizedBox(height: 28),
          _signatures(signature),
          if (stamp != null) ...[
            pw.SizedBox(height: 10),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Image(stamp, width: 86, height: 86),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _header({
    required String school,
    required pw.ImageProvider? logo,
    required pw.ImageProvider? photo,
    required pw.ImageProvider? stamp,
    required String studentName,
  }) {
    final portrait = pw.Container(
      width: 62,
      height: 74,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _gold, width: 1.4),
      ),
      child: photo == null
          ? pw.Center(
              child: pw.Text(
                studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
            )
          : pw.Image(photo, fit: pw.BoxFit.cover),
    );
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const pw.BoxDecoration(color: _navy),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 46,
              height: 46,
              padding: const pw.EdgeInsets.all(3),
              color: PdfColors.white,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  school,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'OFFICIAL GRADE REPORT',
                  style: pw.TextStyle(
                    color: _gold,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          if (stamp == null)
            portrait
          else
            pw.SizedBox(
              width: 62,
              height: 74,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: portrait,
                  ),
                  pw.Positioned(
                    left: 6,
                    right: 2,
                    bottom: 1,
                    child: pw.SizedBox(
                      height: 36,
                      child: pw.Image(stamp, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _identity(StudentGradeReport report) {
    final bits = <String>[
      report.className,
      report.term,
      if (report.academicYear != null && report.academicYear!.trim().isNotEmpty)
        report.academicYear!.trim(),
      if (report.studentId != null && report.studentId!.trim().isNotEmpty)
        'ID ${report.studentId!.trim()}',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          report.studentName,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          bits.join('  |  '),
          style: const pw.TextStyle(fontSize: 10, color: _muted),
        ),
        if (!report.reportCardPublished)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              'Draft - not yet published to parents',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.orange800,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _stats(StudentGradeReport report, String attendance) {
    pw.Widget cell(String label, String value) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: const PdfColor.fromInt(0xFFE4E7EB)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        cell('Average', '${report.average.toStringAsFixed(1)}%'),
        cell('GPA', report.gpa.toStringAsFixed(2)),
        cell('Attendance', attendance),
      ],
    );
  }

  pw.Widget _subjectTable(List<ReportCardSubjectLine> lines) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Subject', 'Score', 'Grade'],
      data: [
        for (final line in lines) [line.subject, line.scoreLabel, line.grade],
      ],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.4),
        2: const pw.FlexColumnWidth(0.8),
      },
      cellAlignments: {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF7F5F0),
      ),
    );
  }

  pw.Widget _signatures(pw.ImageProvider? principalSignature) {
    pw.Widget block(String role, {pw.ImageProvider? image}) {
      return pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              height: 36,
              alignment: pw.Alignment.bottomLeft,
              child: image == null
                  ? pw.SizedBox(height: 36)
                  : pw.Image(image, height: 32, fit: pw.BoxFit.contain),
            ),
            pw.Container(
              height: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _ink, width: 0.6),
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              role,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.Text(
              'Signature',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            block('Homeroom teacher'),
            pw.SizedBox(width: 28),
            block('Principal', image: principalSignature),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            pw.Text(
              'Date',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Container(
              width: 140,
              height: 16,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _ink, width: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> deliver({
    required StudentGradeReport report,
    String? schoolName,
    Uint8List? logoBytes,
    Uint8List? photoBytes,
    Uint8List? stampBytes,
    Uint8List? signatureBytes,
    required bool openForPrint,
  }) async {
    final resolvedLogo = logoBytes ?? await resolveLogoBytes(null);
    final resolvedPhoto = photoBytes ?? await resolvePhotoBytes(report);
    final resolvedStamp =
        stampBytes ?? await resolveMarkBytes(null, SchoolMarkKind.stamp);
    final resolvedSignature = signatureBytes ??
        await resolveMarkBytes(null, SchoolMarkKind.principalSignature);
    final bytes = await buildBytes(
      report: report,
      schoolName: schoolName,
      logoBytes: resolvedLogo,
      photoBytes: resolvedPhoto,
      stampBytes: resolvedStamp,
      signatureBytes: resolvedSignature,
    );
    final fileName = fileNameFor(report);
    final subject = 'Grade report - ${report.studentName}';
    if (kIsWeb) {
      if (openForPrint) {
        await WebFileUtils.openOrDownload(
          filePath: fileName,
          fileName: fileName,
          bytes: bytes,
        );
      } else {
        await WebFileUtils.downloadBytes(fileName: fileName, bytes: bytes);
      }
      return;
    }
    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: fileName,
        ),
      ],
      subject: subject,
      text: subject,
    );
  }
}
