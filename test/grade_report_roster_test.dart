import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  test('grade reports use the live class and drop leftover demo students', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1A-GR';
    final students = <AdminStudentRecord>[];
    for (var i = 1; i <= 5; i++) {
      final student = StudentRegistryService.instance.addStudent(
        schoolId: 'MAL838',
        fullName: 'Maya Student $i',
        grade: 'KG',
        className: className,
        dateOfBirth: DateTime(2019, 4, i.clamp(1, 28)),
      );
      data.syncChildFromRegistry(student.studentId);
      students.add(student);
    }

    data.applyPersistedGradeReports([
      for (var i = 0; i < students.length; i++)
        StudentGradeReport(
          studentName: students[i].fullName,
          studentId: students[i].studentId,
          className: className,
          term: 'Term 1',
          subjects: [
            SubjectGrade(
              subject: 'Literacy',
              score: i == 4 ? 40 : 90 - i.toDouble(),
              maxScore: 100,
              status: SubjectGradeStatus.approved,
              publishedToParents: true,
            ),
          ],
        ),
    ]);

    final visible = data.getAllGradeReports();
    expect(
      visible.any((r) => r.studentName == 'Kidus Bekele'),
      isFalse,
    );
    expect(visible.any((r) => r.className == 'Grade 2C'), isFalse);
    expect(visible.any((r) => r.className == 'Grade 4A'), isFalse);
    expect(
      visible.map((r) => r.studentName),
      containsAll(students.map((s) => s.fullName)),
    );

    final classReports = data.getGradeReportsForClass(className);
    expect(classReports, hasLength(5));
    expect(
      classReports.every((r) => r.className == className),
      isTrue,
    );

    final snapshot = GradeAnalyticsService.instance.buildSnapshot();
    expect(
      snapshot.topScorers.any((g) => g.gradeLevel.contains('Grade 2')),
      isFalse,
    );
    expect(
      snapshot.topScorers.expand((g) => g.gradeTopTen).map((e) => e.report.studentName),
      isNot(contains('Kidus Bekele')),
    );

    final names = snapshot.topScorers
        .expand((g) => g.gradeTopTen)
        .map((e) => e.report.studentName)
        .toSet();
    expect(names, containsAll(['Maya Student 1', 'Maya Student 2', 'Maya Student 3', 'Maya Student 4']));
    expect(
      snapshot.underperformers.fold<int>(0, (sum, g) => sum + g.totalCount),
      1,
    );
    expect(
      snapshot.topScorers.expand((g) => g.sections).map((s) => s.className),
      contains(className),
    );
  });

  test('students without entered marks are not counted as needing support', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1B-GR';
    for (var i = 1; i <= 3; i++) {
      final student = StudentRegistryService.instance.addStudent(
        schoolId: 'MAL838',
        fullName: 'Unmarked $i',
        grade: 'KG',
        className: className,
        dateOfBirth: DateTime(2019, 5, i),
      );
      data.syncChildFromRegistry(student.studentId);
    }

    final first = StudentRegistryService.instance
        .studentsForClass(className, schoolId: 'MAL838')
        .first;
    data.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: first.fullName,
        studentId: first.studentId,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Numeracy',
            score: 92,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
            publishedToParents: true,
          ),
        ],
      ),
    ]);

    final snapshot = GradeAnalyticsService.instance.buildSnapshot();
    final classTops = snapshot.topScorers
        .expand((g) => g.sections)
        .where((s) => s.className == className)
        .expand((s) => s.students)
        .toList();
    expect(classTops, hasLength(1));
    expect(classTops.single.report.studentName, first.fullName);

    expect(
      snapshot.underperformers
          .expand((g) => g.sections)
          .where((s) => s.className == className)
          .expand((s) => s.students),
      isEmpty,
    );
  });

  test('draft and pending marks stay off ranking until approved', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1C-GR';
    final high = StudentRegistryService.instance.addStudent(
      schoolId: 'MAL838',
      fullName: 'Rank High',
      grade: 'KG',
      className: className,
      dateOfBirth: DateTime(2019, 6, 1),
    );
    final low = StudentRegistryService.instance.addStudent(
      schoolId: 'MAL838',
      fullName: 'Rank Low',
      grade: 'KG',
      className: className,
      dateOfBirth: DateTime(2019, 6, 2),
    );
    data.syncChildFromRegistry(high.studentId);
    data.syncChildFromRegistry(low.studentId);

    data.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: high.fullName,
        studentId: high.studentId,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Literacy',
            score: 95,
            maxScore: 100,
            status: SubjectGradeStatus.pendingApproval,
          ),
        ],
      ),
      StudentGradeReport(
        studentName: low.fullName,
        studentId: low.studentId,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Literacy',
            score: 32,
            maxScore: 100,
          ),
        ],
      ),
    ]);

    var snapshot = GradeAnalyticsService.instance.buildSnapshot();
    expect(
      snapshot.topScorers
          .expand((g) => g.sections)
          .where((s) => s.className == className)
          .expand((s) => s.students),
      isEmpty,
    );
    expect(
      snapshot.underperformers
          .expand((g) => g.sections)
          .where((s) => s.className == className)
          .expand((s) => s.students),
      isEmpty,
    );
    expect(
      GradeAnalyticsService.instance.rankingsForClass(className),
      isEmpty,
    );

    data.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: high.fullName,
        studentId: high.studentId,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Literacy',
            score: 95,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
            publishedToParents: true,
          ),
        ],
      ),
      StudentGradeReport(
        studentName: low.fullName,
        studentId: low.studentId,
        className: className,
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Literacy',
            score: 32,
            maxScore: 100,
            status: SubjectGradeStatus.approved,
            publishedToParents: true,
          ),
        ],
      ),
    ]);

    snapshot = GradeAnalyticsService.instance.buildSnapshot();
    final tops = snapshot.topScorers
        .expand((g) => g.sections)
        .where((s) => s.className == className)
        .expand((s) => s.students)
        .map((e) => e.report.studentName)
        .toList();
    final lows = snapshot.underperformers
        .expand((g) => g.sections)
        .where((s) => s.className == className)
        .expand((s) => s.students)
        .map((r) => r.studentName)
        .toList();
    expect(tops, contains('Rank High'));
    expect(tops, isNot(contains('Rank Low')));
    expect(lows, contains('Rank Low'));
    expect(lows, isNot(contains('Rank High')));
  });
}
