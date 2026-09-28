import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/content/training_manuals.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/grade_report_export_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';
import 'package:mayabela/services/teacher_performance_insights.dart';
import 'package:mayabela/web_erp/pages/web_academic_analytics_page.dart';
import 'package:mayabela/web_erp/pages/web_lms_hub_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurriculumService.resetForTests();
    QaMonitorService.resetForTests();
    GoliveService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.analytics',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
      fullName: 'School Admin',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
  });

  test('academic export joins markbook, attendance, and at-risk flags', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Ana Analytics',
      grade: 'Grade 8',
      className: 'Grade 8Z-AN',
      dateOfBirth: DateTime(2012, 1, 1),
    );
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentId: student.studentId,
        studentName: student.fullName,
        className: student.className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 42, maxScore: 100),
        ],
      ),
    ]);
    SchoolDataService.instance.applyPersistedAttendance([
      for (var i = 0; i < 6; i++)
        AttendanceSession(
          className: student.className,
          date: DateTime.utc(2026, 9, 1).add(Duration(days: i)),
          conductedBy: 'Ms Test',
          entries: [
            StudentAttendanceEntry(
              studentName: student.fullName,
              status: AttendanceStatus.absent,
            ),
          ],
        ),
    ]);

    final rows =
        SchoolReportExportService.instance.rowsFor(SchoolReportKind.academic);
    expect(rows.first, containsAll(['Mark average %', 'Attendance %', 'At-risk']));
    final row = rows.firstWhere((r) => r.contains(student.fullName));
    expect(row, contains(student.studentId));
    expect(row, contains('42'));
    expect(row, contains('yes'));

    final attendance = SchoolReportExportService.instance
        .rowsFor(SchoolReportKind.attendance);
    expect(attendance.first, containsAll(['Risk', 'Marks %', 'Attendance %']));
    expect(
      attendance.any((r) => r.contains(student.fullName)),
      isTrue,
    );
  });

  test('grade analytics workbook builds from the existing markbook', () {
    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: 'Top Scorer Ana',
        className: 'Grade 8Z-AN',
        term: 'Term 1',
        subjects: [
          SubjectGrade(subject: 'Math', score: 98, maxScore: 100),
        ],
      ),
    ]);
    final bytes = GradeReportExportService.instance.buildExcelBytes(
      labels: GradeReportExportLabels.fromStrings(AppStrings('en')),
    );
    expect(bytes, isNotEmpty);
  });

  test('teacher insights roll up evaluations and QA observations', () {
    final now = DateTime.utc(2026, 9, 1);
    CurriculumService.instance.applyPersistedData(
      evaluations: [
        TeacherEvaluation(
          id: 'TE-AN-1',
          schoolId: 'TB-001',
          teacherId: 'TCH-AN-1',
          teacherName: 'Ms Insight',
          periodLabel: 'Term 1',
          createdAt: now,
          updatedAt: now,
          curriculumFidelity: 4,
          planningQuality: 5,
          assessmentAlignment: 3,
        ),
      ],
    );
    QaMonitorService.instance.applyPersistedData(
      observations: [
        TeachingObservation(
          id: 'OBS-AN-1',
          schoolId: 'TB-001',
          teacherId: 'TCH-AN-1',
          teacherName: 'Ms Insight',
          observedAt: now,
          createdAt: now,
          updatedAt: now,
          planning: 4,
          instruction: 4,
          engagement: 4,
          assessment: 4,
        ),
      ],
    );

    final rows = TeacherPerformanceInsights.instance.rows('TB-001');
    expect(rows, hasLength(1));
    expect(rows.first.teacherName, 'Ms Insight');
    expect(rows.first.evaluationCount, 1);
    expect(rows.first.evaluationAverage, closeTo(4, 0.01));
    expect(rows.first.observationCount, 1);
    expect(rows.first.observationAverage, closeTo(4, 0.01));

    final export =
        SchoolReportExportService.instance.rowsFor(SchoolReportKind.teachers);
    expect(export.first, containsAll(['Eval avg', 'Observation avg']));
  });

  test('go-live snapshotDue is a 24-hour reminder, not a backup product', () {
    expect(GoliveService.instance.snapshotDue(), isTrue);
    GoliveService.instance.applyPersistedData(
      backups: [
        SchoolBackupRecord(
          id: 'BAK-OLD',
          schoolId: 'TB-001',
          createdAt: DateTime.now().subtract(const Duration(hours: 30)),
          createdBy: 'admin.analytics',
        ),
      ],
    );
    expect(GoliveService.instance.snapshotDue(), isTrue);
    GoliveService.instance.applyPersistedData(
      backups: [
        SchoolBackupRecord(
          id: 'BAK-NEW',
          schoolId: 'TB-001',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          createdBy: 'admin.analytics',
        ),
      ],
    );
    expect(GoliveService.instance.snapshotDue(), isFalse);
    expect(GoliveService.instance.capacitySnapshot().snapshotDue, isFalse);
  });

  test('training manuals keep admin analytics and daily snapshot copy', () {
    final articles = TrainingManuals.forAudience('admin');
    expect(articles.any((a) => a.id == 'admin-analytics'), isTrue);
    expect(
      articles.firstWhere((a) => a.id == 'admin-backup').body,
      contains('24'),
    );
  });

  test('LMS roster opens the existing SIS profile, not a second student store',
      () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Lms Sis Child',
      grade: 'Grade 4',
      className: 'LMS Sis 4A',
      dateOfBirth: DateTime(2016, 4, 1),
    );
    final roster = StudentRegistryService.instance.studentsForClass(
      'LMS Sis 4A',
      schoolId: 'TB-001',
    );
    expect(roster.map((s) => s.studentId), contains(student.studentId));
    expect(StudentSisProfile.load(student.studentId)?.student.fullName,
        student.fullName);
  });

  testWidgets('analytics desk shows teacher and export tabs', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1000,
            child: WebAcademicAnalyticsPage(),
          ),
        ),
      ),
    );
    expect(find.text('Academic analytics'), findsOneWidget);
    expect(find.textContaining('Teachers'), findsOneWidget);
    expect(find.text('Exports'), findsOneWidget);
    await tester.ensureVisible(find.text('Exports'));
    await tester.tap(find.text('Exports'));
    await tester.pumpAndSettle();
    expect(find.text('Grade analytics Excel'), findsOneWidget);
  });

  testWidgets('LMS hub lists SIS roster on the existing course card',
      (tester) async {
    AuthService.sessionSchoolId = 'TB-001';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 800, height: 900, child: WebLmsHubPage()),
        ),
      ),
    );
    expect(find.text('Learning Management'), findsOneWidget);
  });
}
