import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/widgets/grade_average_breakdown_sheet.dart';

StudentGradeReport _report({
  required List<SubjectGrade> subjects,
  String name = 'Amina Haile',
}) {
  return StudentGradeReport(
    studentName: name,
    className: 'Grade 4A',
    term: 'Term 1',
    subjects: subjects,
  );
}

SubjectGrade _subject(
  String name,
  double score, {
  SubjectGradeStatus status = SubjectGradeStatus.draft,
  List<AssessmentMark>? assessments,
}) {
  return SubjectGrade(
    subject: name,
    score: score,
    maxScore: 100,
    status: status,
    publishedToParents: status == SubjectGradeStatus.approved,
    assessments: assessments,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocale.instance.load();
  });

  test('approvedSubjectsForAverage ignores draft and pending marks', () {
    final report = _report(
      subjects: [
        _subject('Math', 90, status: SubjectGradeStatus.approved),
        _subject('English', 80, status: SubjectGradeStatus.approved),
        _subject('History', 40),
        _subject('Science', 100, status: SubjectGradeStatus.pendingApproval),
      ],
    );

    final approved = GradeAnalyticsService.approvedSubjectsForAverage(report);
    expect(approved.map((s) => s.subject), ['Math', 'English']);
    expect(
      approved.map((s) => s.percentage).reduce((a, b) => a + b) /
          approved.length,
      85,
    );
    expect(report.average, isNot(85));
  });

  testWidgets(
    'profile sheet lists approved entered subjects behind the average',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final report = _report(
        subjects: [
          _subject(
            'Math',
            90,
            status: SubjectGradeStatus.approved,
            assessments: [
              AssessmentMark(
                categoryId: 'test',
                label: 'Test 1',
                weightPercent: 50,
                score: 90,
              ),
            ],
          ),
          _subject('English', 80, status: SubjectGradeStatus.approved),
          _subject('History', 40),
          _subject('Science', 100, status: SubjectGradeStatus.pendingApproval),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GradeAverageBreakdownSheet(report: report)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amina Haile'), findsOneWidget);
      expect(
        find.text('These approved subjects make this average'),
        findsOneWidget,
      );
      expect(find.textContaining('Average: 85.0%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('approved-subject-Math')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('approved-subject-English')),
        findsOneWidget,
      );
      expect(find.text('Math'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('History'), findsNothing);
      expect(find.text('Science'), findsNothing);
      expect(find.text('Locked after approval'), findsNWidgets(2));
      expect(find.textContaining('Test 1'), findsOneWidget);
    },
  );

  testWidgets(
    'clicking a student profile opens approved subjects for the average',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final report = _report(
        subjects: [
          _subject('Math', 90, status: SubjectGradeStatus.approved),
          _subject('English', 80, status: SubjectGradeStatus.approved),
          _subject('History', 40),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ListTile(
                  title: Text(report.studentName),
                  onTap: () => showGradeAverageBreakdownSheet(context, report),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Amina Haile'));
      await tester.pumpAndSettle();

      expect(find.byType(GradeAverageBreakdownSheet), findsOneWidget);
      expect(
        find.text('These approved subjects make this average'),
        findsOneWidget,
      );
      expect(find.text('Math'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('History'), findsNothing);
    },
  );

  testWidgets('profile sheet empty state when nothing is approved', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeAverageBreakdownSheet(
            report: _report(subjects: [_subject('History', 40)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No approved subjects yet'), findsOneWidget);
    expect(find.text('History'), findsNothing);
    expect(find.byType(ApprovedSubjectAverageRow), findsNothing);
  });
}
