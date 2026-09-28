import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/grade_audit_service.dart';
import 'package:mayabela/services/school_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GradeAuditService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('letter scale stays A–F by default and can be remapped', () {
    expect(MarkbookMath.letterFromPercentage(91), 'A');
    expect(MarkbookMath.letterFromPercentage(72), 'C');
    final settings = MarkbookSettings.fromMap({
      'categories': MarkbookSettings.liaDefaults.categories
          .map((c) => c.toMap())
          .toList(),
      'letterBands': [
        {'letter': 'HD', 'minPercent': 85},
        {'letter': 'P', 'minPercent': 50},
        {'letter': 'F', 'minPercent': 0},
      ],
    });
    expect(
      MarkbookMath.letterFromPercentage(88, bands: settings.letterBands),
      'HD',
    );
    expect(
      MarkbookMath.letterFromPercentage(52, bands: settings.letterBands),
      'P',
    );
  });

  test('term reports stay isolated and feed a student trend', () {
    final data = SchoolDataService.instance;
    final t1 = data.openTermGradeReport(
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      term: 'Term 1',
      academicYear: '2026',
    );
    final t2 = data.openTermGradeReport(
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      term: 'Term 2',
      academicYear: '2026',
    );
    expect(identical(t1, t2), isFalse);
    expect(
      data.openTermGradeReport(
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        term: 'Term 1',
        academicYear: '2026',
      ),
      same(t1),
    );

    t1.subjects.add(
      SubjectGrade(subject: 'Science', score: 80, maxScore: 100),
    );
    t2.subjects.add(
      SubjectGrade(subject: 'Science', score: 90, maxScore: 100),
    );

    final trend = GradeAnalyticsService.instance
        .termTrendForStudent(studentName: 'Sara Bekele')
        .where((p) => p.academicYear == '2026')
        .toList();
    expect(trend, hasLength(2));
    expect(trend.first.term, 'Term 1');
    expect(trend.first.average, 80);
    expect(trend.last.term, 'Term 2');
    expect(trend.last.average, 90);
  });

  test('category averages break down assessment types', () {
    final data = SchoolDataService.instance;
    data.addSubjectToGradeReport(
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      subject: 'Science',
      teacherId: 'TCH-1',
    );
    data.updateSubjectGrade(
      studentName: 'Sara Bekele',
      className: 'Grade 4A',
      subject: 'Science',
      score: 80,
      assessments: [
        AssessmentMark(
          categoryId: 'quiz',
          label: 'Quizzes',
          weightPercent: 15,
          score: 70,
        ),
        AssessmentMark(
          categoryId: 'final',
          label: 'Final exam',
          weightPercent: 35,
          score: 90,
        ),
      ],
    );
    final rows = GradeAnalyticsService.instance.categoryAverages(
      className: 'Grade 4A',
      subject: 'Science',
    );
    expect(rows.map((r) => r.categoryId), containsAll(['quiz', 'final']));
    expect(rows.firstWhere((r) => r.categoryId == 'quiz').average, 70);
    expect(rows.firstWhere((r) => r.categoryId == 'final').average, 90);
  });

  test('grade audit log is readable after a workflow event', () async {
    await GradeAuditService.instance.log(
      action: GradeAuditAction.submitted,
      schoolId: 'TB-001',
      className: 'Grade 4A',
      subject: 'Science',
      studentName: 'Sara Bekele',
      actorName: 'Ms Hana',
      detail: 'Submitted for approval',
    );
    final recent = GradeAuditService.instance.recentForSchool('TB-001');
    expect(recent, isNotEmpty);
    expect(recent.first.action, GradeAuditAction.submitted);
    expect(
      GradeAuditService.instance
          .forStudent(studentName: 'Sara Bekele', subject: 'Science'),
      hasLength(1),
    );
  });
}
