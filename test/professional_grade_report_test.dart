import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/report_card_layout.dart';
import 'package:mayabela/services/report_card_pdf_service.dart';
import 'package:mayabela/widgets/term_report_card_view.dart';

/// 1×1 PNG so the watermark can be decoded in tests.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

StudentGradeReport _report() {
  return StudentGradeReport(
    studentName: 'Belen Teacher',
    studentId: 'STU-014',
    className: 'Grade 8A',
    term: 'Term 1',
    academicYear: '2026',
    reportCardPublished: true,
    principalComment: 'A steady term.',
    subjects: [
      SubjectGrade(
        subject: 'Mathematics',
        score: 86,
        maxScore: 100,
        comment: 'Clear written work.',
        publishedToParents: true,
        assessments: [
          AssessmentMark(
            categoryId: 'midterm',
            label: 'Midterm',
            weightPercent: 40,
            score: 80,
          ),
        ],
      ),
      SubjectGrade(
        subject: 'English',
        score: 74,
        maxScore: 100,
        publishedToParents: true,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subject table lines keep descriptions out of the subject name', () {
    final lines = ReportCardLayout.lines(_report());
    expect(lines.map((line) => line.subject), ['Mathematics', 'English']);
    expect(lines.first.scoreLabel, '86.0 / 100');
    expect(lines.first.remark, contains('Midterm'));
    expect(lines.first.remark, contains('Clear written work.'));
    expect(lines.last.remark, isNull);
    expect(lines.first.subject, isNot(contains('Midterm')));
  });

  test('official grade report PDF includes a principal signature block', () async {
    final bytes = await ReportCardPdfService.instance.buildBytes(
      report: _report(),
      schoolName: 'Mayu International Academy',
      logoBytes: _png,
      photoBytes: _png,
      stampBytes: _png,
      signatureBytes: _png,
    );
    expect(bytes.length, greaterThan(400));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      ReportCardPdfService.instance.fileNameFor(_report()),
      'grade_report_STU_014_Term_1.pdf',
    );
  });

  testWidgets('report card shows the photo, watermark, signature, and print',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TermReportCardView(
              report: _report(),
              schoolName: 'Mayu International Academy',
              showActions: true,
              showSubjectRemarks: false,
              logoBytes: _png,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mayu International Academy'), findsOneWidget);
    expect(find.text('OFFICIAL GRADE REPORT'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-watermark')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-photo-stamp')), findsNothing);
    expect(find.byKey(const ValueKey('report-card-bottom-stamp')), findsNothing);
    expect(
      find.byKey(const ValueKey('report-card-principal-signature')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('report-card-principal-sign')),
      findsOneWidget,
    );
    expect(find.text('Principal'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-download')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-print')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-card-subject-Mathematics')),
      findsOneWidget,
    );
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.textContaining('Midterm'), findsNothing);
    expect(find.text('Clear written work.'), findsNothing);
  });

  testWidgets('remarks sit under the subject table when the card stands alone',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TermReportCardView(
              report: _report(),
              schoolName: 'Mayu International Academy',
              showSubjectRemarks: true,
              logoBytes: _png,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Subject remarks'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-card-remark-Mathematics')),
      findsOneWidget,
    );
    expect(find.textContaining('Midterm'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-download')), findsNothing);
  });

  testWidgets('stamp covers the photo and the bottom, signature on principal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 980));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TermReportCardView(
              report: _report(),
              schoolName: 'Mayu International Academy',
              showActions: false,
              logoBytes: _png,
              stampBytes: _png,
              signatureBytes: _png,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('report-card-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-photo-stamp')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-card-bottom-stamp')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report-card-principal-signature')),
      findsOneWidget,
    );
    expect(find.text('OFFICIAL GRADE REPORT'), findsOneWidget);
  });
}
