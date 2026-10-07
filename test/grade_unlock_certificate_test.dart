import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_report_certificate_service.dart';
import 'package:mayabela/services/grade_workflow_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/grade_report_certificate_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocale.instance.load();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.mal838',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAL838',
      fullName: 'Nabil Ahmed',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  StudentGradeReport seedApprovedReport({
    required AdminStudentRecord student,
    required List<SubjectGrade> subjects,
  }) {
    final report = StudentGradeReport(
      studentName: student.fullName,
      studentId: student.studentId,
      className: student.className,
      term: 'Term 1',
      academicYear: '2018 E.C.',
      subjects: subjects,
    );
    SchoolDataService.instance.applyPersistedGradeReports([report]);
    return SchoolDataService.instance.getGradeReportForStudentId(
          student.studentId,
        ) ??
        report;
  }

  test('teacher cannot unlock an approved grade', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.mal838',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'MAL838',
      fullName: 'Sara Teacher',
    );
    expect(GradeWorkflowService.canUserUnlockApprovedGrades, isFalse);

    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'MAL838',
      fullName: 'Unlock Deny Student',
      grade: 'KG',
      className: 'KG 1U-GR',
      dateOfBirth: DateTime(2019, 1, 8),
    );
    SchoolDataService.instance.syncChildFromRegistry(student.studentId);
    seedApprovedReport(
      student: student,
      subjects: [
        SubjectGrade(
          subject: 'Literacy',
          score: 88,
          maxScore: 100,
          status: SubjectGradeStatus.approved,
          publishedToParents: true,
        ),
      ],
    );

    expect(
      SchoolDataService.instance.adminUnlockSubjectGrade(
        studentName: student.fullName,
        className: student.className,
        subject: 'Literacy',
        reason: 'Agreed correction',
      ),
      isFalse,
    );
    expect(
      SchoolDataService.instance
          .getGradeReportForStudent(student.fullName)!
          .subjects
          .single
          .status,
      SubjectGradeStatus.approved,
    );
  });

  test('admin unlocks an approved report for an agreed edit', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'MAL838',
      fullName: 'Unlock Allow Student',
      grade: 'KG',
      className: 'KG 1V-GR',
      dateOfBirth: DateTime(2019, 2, 8),
    );
    SchoolDataService.instance.syncChildFromRegistry(student.studentId);
    seedApprovedReport(
      student: student,
      subjects: [
        SubjectGrade(
          subject: 'Literacy',
          score: 91,
          maxScore: 100,
          status: SubjectGradeStatus.approved,
          publishedToParents: true,
        ),
        SubjectGrade(
          subject: 'Numeracy',
          score: 40,
          maxScore: 100,
          status: SubjectGradeStatus.approved,
          publishedToParents: true,
        ),
      ],
    );

    expect(GradeWorkflowService.canUserUnlockApprovedGrades, isTrue);
    expect(
      GradeAnalyticsService.instance.rankingsForClass(student.className),
      isNotEmpty,
    );

    final unlocked =
        SchoolDataService.instance.adminUnlockApprovedGradeReport(
      studentName: student.fullName,
      className: student.className,
      reason: 'Parent and teacher agreed to correct Numeracy',
      adminId: 'admin.mal838',
      adminName: 'Nabil Ahmed',
    );
    expect(unlocked, 2);

    final report = SchoolDataService.instance.getGradeReportForStudent(
      student.fullName,
    )!;
    expect(
      report.subjects.every((g) => g.status == SubjectGradeStatus.draft),
      isTrue,
    );
    expect(report.subjects.every((g) => g.canTeacherEdit), isTrue);
    expect(report.subjects.every((g) => !g.publishedToParents), isTrue);
    expect(
      report.subjects.first.reviewComment,
      'Parent and teacher agreed to correct Numeracy',
    );
    expect(
      GradeAnalyticsService.instance.rankingsForClass(student.className),
      isEmpty,
    );
  });

  test('grade report certificate uses school name and student information',
      () async {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'MAL838',
      fullName: 'Certificate Student',
      grade: 'KG',
      className: 'KG 1W-GR',
      dateOfBirth: DateTime(2019, 3, 8),
      gender: 'Female',
    );
    SchoolDataService.instance.syncChildFromRegistry(student.studentId);
    final report = seedApprovedReport(
      student: student,
      subjects: [
        SubjectGrade(
          subject: 'Literacy',
          score: 90,
          maxScore: 100,
          status: SubjectGradeStatus.approved,
          publishedToParents: true,
        ),
        SubjectGrade(
          subject: 'History',
          score: 40,
          maxScore: 100,
        ),
      ],
    );

    final cert =
        GradeReportCertificateService.instance.buildSnapshot(report);
    final schoolName =
        SchoolRegistryService.instance.displayName('MAL838');
    expect(cert.schoolName, schoolName);
    expect(cert.schoolName.toUpperCase(), isNot('MAL838'));
    expect(cert.studentName, 'Certificate Student');
    expect(cert.studentId, student.studentId);
    expect(cert.className, student.className);
    expect(cert.gradeLevel, 'KG');
    expect(cert.subjects.map((s) => s.subject), ['Literacy']);
    expect(cert.average, 90);

    final pdf = await GradeReportCertificateService.instance
        .buildPdfFromSnapshot(cert);
    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });

  testWidgets('certificate view shows school and student identity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cert = GradeReportCertificateSnapshot(
      schoolName: 'Mayu International Academy',
      studentName: 'Amina Haile',
      studentId: 'ST-4411',
      className: 'Grade 4A',
      gradeLevel: 'Grade 4',
      term: 'Term 1',
      academicYear: '2018 E.C.',
      issuedAt: DateTime(2026, 10, 7),
      subjects: [
        SubjectGrade(
          subject: 'Math',
          score: 90,
          maxScore: 100,
          status: SubjectGradeStatus.approved,
        ),
      ],
      attendance: const StudentAttendanceSnapshot(present: 17, absent: 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GradeReportCertificateView(certificate: cert),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Mayu International Academy'), findsOneWidget);
    expect(find.text('Grade Report Certificate'), findsOneWidget);
    expect(find.text('Amina Haile'), findsOneWidget);
    expect(find.text('ST-4411'), findsOneWidget);
    expect(find.text('Grade 4A'), findsOneWidget);
    expect(find.text('Math'), findsOneWidget);
    expect(find.text('MAL838'), findsNothing);
  });
}
