import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/year_start_sheet_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  void signIn({
    required String username,
    required String roleKey,
    List<String> staffRoles = const [],
  }) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: 'TB-001',
      fullName: username,
      staffRoles: staffRoles,
    );
  }

  Future<void> verifyAllDocs(String id) async {
    final app = AdmissionService.instance.byId(id)!;
    for (final doc in app.documents) {
      await AdmissionService.instance.setDocument(
        id,
        doc.id,
        submitted: true,
        verified: true,
      );
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdmissionService.resetForTests();
    NotificationService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    AdmissionService.resetForTests();
    NotificationService.instance.resetForTests();
  });

  test('enroll requires date of birth and verified documents', () async {
    signIn(username: 'reg.p3', roleKey: AuthService.roleTeacher, staffRoles: [
      StaffRoles.registrar,
    ]);
    final missingDob = await AdmissionService.instance.createInquiry(
      fullName: 'No Dob',
      schoolId: 'TB-001',
      stage: AdmissionStage.offered,
    );
    await verifyAllDocs(missingDob.id);
    await expectLater(
      AdmissionService.instance.enroll(
        missingDob.id,
        className: 'Grade 3A',
        grade: 'Grade 3',
      ),
      throwsA(isA<StateError>()),
    );

    final missingDocs = await AdmissionService.instance.createInquiry(
      fullName: 'No Docs',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2016, 2, 2),
      stage: AdmissionStage.offered,
    );
    await expectLater(
      AdmissionService.instance.enroll(
        missingDocs.id,
        className: 'Grade 3A',
        grade: 'Grade 3',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('enroll emails the parent invite when a guardian email is on file',
      () async {
    signIn(username: 'reg.p3', roleKey: AuthService.roleTeacher, staffRoles: [
      StaffRoles.registrar,
    ]);
    final created = await AdmissionService.instance.createInquiry(
      fullName: 'Phase Three Kidus',
      gradeApplying: 'Grade 3',
      schoolId: 'TB-001',
      dateOfBirth: DateTime(2016, 5, 5),
      guardianName: 'Parent Three',
      guardianEmail: 'parent.p3@example.com',
      stage: AdmissionStage.offered,
    );
    await verifyAllDocs(created.id);
    final student = await AdmissionService.instance.enroll(
      created.id,
      className: 'Grade 3P3',
      grade: 'Grade 3',
    );
    expect(student, isNotNull);
    expect(student!.dateOfBirth, DateTime(2016, 5, 5));
    expect(
      NotificationService.instance.itemsForTests().any(
            (n) =>
                n.title.contains('Parent invite') &&
                n.targetStudentId == student.studentId &&
                n.body.contains(student.studentId),
          ),
      isTrue,
    );
  });

  test('VP can approve external transfers; Academic Admin cannot', () {
    signIn(
      username: 'vp.p3',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(TransferPermissions.canApproveExternalTransfers, isTrue);
    expect(TransferPermissions.canApproveInternalTransfers, isTrue);

    signIn(
      username: 'ac.p3',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.academicAdmin],
    );
    expect(TransferPermissions.canApproveExternalTransfers, isFalse);

    signIn(
      username: 'sd.p3',
      roleKey: AuthService.roleTeacher,
      staffRoles: const [StaffRoles.sectionDirector],
    );
    expect(TransferPermissions.canApproveExternalTransfers, isFalse);
  });

  test('attendance class CSV exports roster and imports marks', () {
    const className = 'Grade 3P3';
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-P3A',
        fullName: 'Phase Three Alpha',
        grade: 'Grade 3',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 1, 1),
      ),
      AdminStudentRecord(
        studentId: 'STU-P3B',
        fullName: 'Phase Three Beta',
        grade: 'Grade 3',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 2, 2),
      ),
    ]);
    signIn(username: 'admin.p3', roleKey: AuthService.roleAdmin);
    final date = DateTime(2026, 10, 4);
    final blank = YearStartSheetService.instance.attendanceCsv(
      className: className,
      date: date,
      schoolId: 'TB-001',
    );
    expect(blank, contains('STU-P3A'));
    expect(blank, contains('Phase Three Beta'));

    final imported = YearStartSheetService.instance.importAttendanceCsv(
      'Class,Date,Student ID,Name,Status\n'
      '$className,2026-10-04,STU-P3A,Phase Three Alpha,P\n'
      '$className,2026-10-04,STU-P3B,Phase Three Beta,A\n',
      conductedBy: 'admin.p3',
    );
    expect(imported, 2);
    final session = SchoolDataService.instance.getAttendanceSession(
      className,
      date,
    );
    expect(session, isNotNull);
    expect(
      session!.entries
          .firstWhere((e) => e.studentId == 'STU-P3A')
          .status,
      AttendanceStatus.present,
    );
    expect(
      session.entries.firstWhere((e) => e.studentId == 'STU-P3B').status,
      AttendanceStatus.absent,
    );
  });

  test('grade class CSV imports a homework score into the markbook', () {
    const className = 'Grade 3P3G';
    const subject = 'Phase3 Science';
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-P3G',
        fullName: 'Phase Three Grade',
        grade: 'Grade 3',
        className: className,
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 3, 3),
      ),
    ]);
    signIn(username: 'admin.p3', roleKey: AuthService.roleAdmin);
    final csv = YearStartSheetService.instance.gradeCsv(
      className: className,
      subject: subject,
      schoolId: 'TB-001',
    );
    expect(csv, contains('homework'));
    expect(csv, contains('Phase Three Grade'));

    final n = YearStartSheetService.instance.importGradeCsv(
      'Class,Subject,Student ID,Name,homework\n'
      '$className,$subject,STU-P3G,Phase Three Grade,91\n',
      teacherId: 'admin.p3',
    );
    expect(n, greaterThan(0));
    final report = SchoolDataService.instance.getGradeReportForStudent(
      'Phase Three Grade',
    );
    expect(report, isNotNull);
    final grade = report!.subjects.firstWhere((s) => s.subject == subject);
    expect(
      grade.assessments.any((m) => m.categoryId == 'homework' && m.score == 91),
      isTrue,
    );
  });

  test('public apply and enroll desks collect DOB and email the parent', () {
    final apply = read('lib/screens/public_admission_apply_screen.dart');
    expect(apply, contains('dateOfBirth'));
    expect(apply, contains('Date of birth (required)'));
    expect(apply, contains('Birth certificate'));
    expect(apply, contains('Previous school reports'));
    expect(apply, contains('Parent / guardian national ID'));
    expect(apply, contains('AdmissionExtraPrograms'));
    expect(apply, contains('Extra programmes'));
    final programs = read('lib/models/admission_extra_program.dart');
    expect(programs, contains('Film & editing class'));
    expect(programs, contains('Sport / football class'));
    expect(programs, contains('AI learning class'));
    expect(programs, contains('Visual arts'));

    final desk = read('lib/web_erp/pages/web_admissions_page.dart');
    expect(desk, contains('dateOfBirth: dateOfBirth'));
    expect(desk, contains('guardianEmail: email.text'));

    final submit = read('supabase/functions/school-submit-application/index.ts');
    expect(submit, contains('dateOfBirth is required'));
    expect(submit, contains('dateOfBirth,'));
    expect(submit, contains('birth-certificate'));
    expect(submit, contains('parent-national-id'));
    expect(submit, contains('extraPrograms'));
    expect(submit, contains('documents_required'));

    final invite = read('supabase/functions/school-invite-parent/index.ts');
    expect(invite, contains('sendPlainEmail'));
    expect(invite, contains('Parent invite'));

    final attendance = read('lib/web_erp/pages/web_attendance_hub_page.dart');
    expect(attendance, contains('Export class CSV'));
    expect(attendance, contains('Import class CSV'));

    final markbook = read('lib/web_erp/pages/web_markbook_page.dart');
    expect(markbook, contains('Export CSV'));
    expect(markbook, contains('importGradeCsv'));
  });
}
