import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('grade approvals stay inside the signed-in school', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-JOSIAH',
        fullName: 'Josiah Yared',
        grade: '1',
        className: 'Grade 1A',
        schoolId: 'MAGIC-SMART',
        dateOfBirth: DateTime(2018, 3, 2),
      ),
      AdminStudentRecord(
        studentId: 'STU-LALI',
        fullName: 'Lali Tena',
        grade: '2',
        className: 'Grade 2A',
        schoolId: 'MAYU-INTL',
        dateOfBirth: DateTime(2017, 6, 9),
      ),
      AdminStudentRecord(
        studentId: 'STU-JOSIAH',
        fullName: 'Other Josiah',
        grade: '1',
        className: 'Grade 1A',
        schoolId: 'MAYU-INTL',
        dateOfBirth: DateTime(2018, 1, 1),
      ),
    ]);

    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: 'Josiah Yared',
        studentId: 'STU-JOSIAH',
        className: 'Grade 1A',
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Physical Education',
            score: 95,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
            submittedAt: DateTime.utc(2026, 10, 1),
            lastReviewedAt: DateTime.utc(2026, 10, 2),
          ),
        ],
      ),
      StudentGradeReport(
        studentName: 'Lali Tena',
        studentId: 'STU-LALI',
        className: 'Grade 2A',
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 95,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
            submittedAt: DateTime.utc(2026, 10, 3),
            lastReviewedAt: DateTime.utc(2026, 10, 4),
          ),
        ],
      ),
    ]);

    AuthService.currentUser = RegisteredUser(
      username: 'mayu.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAYU-INTL',
      fullName: 'Mayu Admin',
    );

    final mayuQueue = SchoolDataService.instance.adminGradeReviewItems(
      schoolId: 'MAYU-INTL',
    );
    expect(
      mayuQueue.map((item) => item.report.studentName),
      isNot(contains('Josiah Yared')),
    );
    expect(
      mayuQueue.map((item) => item.report.studentName),
      contains('Lali Tena'),
    );

    final mayuReports = SchoolDataService.instance.getAllGradeReports();
    expect(
      mayuReports.map((report) => report.studentName),
      isNot(contains('Josiah Yared')),
    );
    expect(
      mayuReports.map((report) => report.studentName),
      contains('Lali Tena'),
    );
    expect(
      SchoolDataService.instance
          .getGradeReportsForClass('Grade 1A')
          .map((report) => report.studentName),
      isNot(contains('Josiah Yared')),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'magic.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAGIC-SMART',
      fullName: 'Magic Admin',
    );

    final magicQueue = SchoolDataService.instance.adminGradeReviewItems(
      schoolId: 'MAGIC-SMART',
    );
    expect(
      magicQueue.map((item) => item.report.studentName),
      contains('Josiah Yared'),
    );
    expect(
      magicQueue.map((item) => item.report.studentName),
      isNot(contains('Lali Tena')),
    );
  });
}
