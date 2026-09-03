import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/markbook.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/markbook_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Markbook math', () {
    test('LIA default weights sum to 100', () {
      expect(MarkbookSettings.liaDefaults.weightsValid, isTrue);
      expect(MarkbookSettings.liaDefaults.weightTotal, 100);
    });

    test('weighted percentage uses category weights', () {
      final marks = [
        AssessmentMark(
          categoryId: 'hw',
          label: 'Homework',
          weightPercent: 10,
          score: 100,
        ),
        AssessmentMark(
          categoryId: 'quiz',
          label: 'Quizzes',
          weightPercent: 15,
          score: 80,
        ),
        AssessmentMark(
          categoryId: 'cw',
          label: 'Classwork',
          weightPercent: 15,
          score: 80,
        ),
        AssessmentMark(
          categoryId: 'mid',
          label: 'Midterm',
          weightPercent: 25,
          score: 70,
        ),
        AssessmentMark(
          categoryId: 'final',
          label: 'Final',
          weightPercent: 35,
          score: 60,
        ),
      ];
      // 10*100 + 15*80 + 15*80 + 25*70 + 35*60 = 1000+1200+1200+1750+2100 = 7250 / 100
      expect(MarkbookMath.weightedPercentage(marks), 72.5);
    });

    test('missing marks are dropped unless counted as zero', () {
      final marks = [
        AssessmentMark(
          categoryId: 'mid',
          label: 'Midterm',
          weightPercent: 40,
          score: 100,
        ),
        AssessmentMark(
          categoryId: 'final',
          label: 'Final',
          weightPercent: 60,
        ),
      ];
      expect(MarkbookMath.weightedPercentage(marks), 100);
      expect(
        MarkbookMath.weightedPercentage(marks, missingCountsAsZero: true),
        40,
      );
      expect(MarkbookMath.isComplete(marks), isFalse);
    });

    test('invalid weights are rejected', () {
      const settings = MarkbookSettings(
        categories: [
          AssessmentCategory(id: 'a', label: 'A', weightPercent: 40),
          AssessmentCategory(id: 'b', label: 'B', weightPercent: 40),
        ],
      );
      expect(settings.weightsValid, isFalse);
      expect(settings.weightError, isNotNull);
    });
  });

  group('Serialization', () {
    test('subject assessments round-trip inside a grade report', () {
      final original = StudentGradeReport(
        studentName: 'Abebe Kebede',
        className: 'Grade 5A',
        term: 'Term 2',
        studentId: 'STU-2001',
        academicYear: '2026/2027',
        homeroomComment: 'Strong term.',
        principalComment: 'Well done.',
        reportCardPublished: true,
        reportCardPublishedAt: DateTime.utc(2026, 6, 1),
        attendancePresent: 40,
        attendanceLate: 2,
        attendanceAbsent: 1,
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 82,
            maxScore: 100,
            assessments: [
              AssessmentMark(
                categoryId: 'midterm',
                label: 'Midterm',
                weightPercent: 40,
                score: 90,
              ),
              AssessmentMark(
                categoryId: 'final',
                label: 'Final exam',
                weightPercent: 60,
                score: 76,
              ),
            ],
          ),
        ],
      );
      original.subjects.first.applyWeightedScore();
      final copy = StudentGradeReport.fromMap(original.toMap());
      expect(copy.term, 'Term 2');
      expect(copy.gpa, greaterThan(0));
      expect(copy.reportCardPublished, isTrue);
      expect(copy.homeroomComment, 'Strong term.');
      expect(copy.subjects.first.assessments, hasLength(2));
      expect(copy.subjects.first.hasMarkbook, isTrue);
      expect(copy.attendanceSnapshot.present, 40);
    });

    test('legacy reports without assessments still parse', () {
      final copy = SubjectGrade.fromMap({
        'subject': 'English',
        'score': 88,
        'maxScore': 100,
      });
      expect(copy.assessments, isEmpty);
      expect(copy.hasMarkbook, isFalse);
      expect(copy.letterGrade, 'B');
    });
  });

  group('Workflow', () {
    const schoolId = 'TB-001';

    void signIn({
      required String username,
      required String roleKey,
      List<String> staffRoles = const [],
    }) {
      AuthService.currentUser = RegisteredUser(
        username: username,
        password: 'x',
        roleKey: roleKey,
        schoolId: schoolId,
        fullName: username,
        staffRoles: staffRoles,
      );
    }

    setUp(() {
      AuthService.currentUser = null;
      SchoolRegistryService.instance.applyPersistedSchools([
        SchoolRecord(
          id: schoolId,
          name: 'Test School',
          gradeLevels: const ['Grade 4'],
          sections: const ['Grade 4A'],
          gradeWorkflow: const GradeWorkflowSettings(
            requireApproval: true,
            approvalChain: [GradeApprovalRole.academicCoordinator],
          ),
        ),
      ]);
    });

    tearDown(() {
      AuthService.currentUser = null;
    });

    test('weighted entry computes final and approval still publishes to parents',
        () {
      final data = SchoolDataService.instance;
      const student = 'Sara Bekele';
      const className = 'Grade 4A';
      const subject = 'Science';

      signIn(username: 'admin.unlock', roleKey: AuthService.roleAdmin);
      data.adminUnlockSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
        adminId: 'ADM-1',
        adminName: 'Admin',
      );

      signIn(username: 'teacher.sci', roleKey: AuthService.roleTeacher);
      final marks = [
        AssessmentMark(
          categoryId: 'homework',
          label: 'Homework',
          weightPercent: 10,
          score: 100,
        ),
        AssessmentMark(
          categoryId: 'quiz',
          label: 'Quizzes',
          weightPercent: 15,
          score: 80,
        ),
        AssessmentMark(
          categoryId: 'classwork',
          label: 'Classwork',
          weightPercent: 15,
          score: 80,
        ),
        AssessmentMark(
          categoryId: 'midterm',
          label: 'Midterm',
          weightPercent: 25,
          score: 70,
        ),
        AssessmentMark(
          categoryId: 'final',
          label: 'Final exam',
          weightPercent: 35,
          score: 60,
        ),
      ];
      final result = MarkbookService.instance.enterClassAssessments(
        className: className,
        subject: subject,
        teacherId: 'TCH-1001',
        assessmentsByStudent: {student: marks},
        submitForApproval: true,
      );
      expect(result.saved, 1);

      var grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.score, closeTo(72.5, 0.01));
      expect(grade.hasMarkbook, isTrue);
      expect(grade.status, SubjectGradeStatus.pendingApproval);
      expect(grade.isVisibleToParent, isFalse);

      signIn(
        username: 'sd.approver',
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.sectionDirector],
      );
      expect(
        data.approveSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          reviewerId: 'SD-1',
          reviewerName: 'Section Director',
          reviewerRole: AuthService.roleTeacher,
        ),
        isTrue,
      );
      grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.isVisibleToParent, isTrue);
      expect(grade.letterGrade, 'C');
    });

    test('report card comments stay hidden until published', () {
      final data = SchoolDataService.instance;
      const student = 'Sara Bekele';
      const className = 'Grade 4A';
      const subject = 'English';

      signIn(username: 'admin.unlock', roleKey: AuthService.roleAdmin);
      data.adminUnlockSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
        adminId: 'ADM-1',
        adminName: 'Admin',
      );
      signIn(username: 'teacher.eng', roleKey: AuthService.roleTeacher);
      expect(
        data.updateSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          score: 92,
          enteredByTeacherId: 'TCH-1001',
        ),
        isTrue,
      );
      expect(
        data.submitSubjectGradeForApproval(
          studentName: student,
          className: className,
          subject: subject,
          teacherId: 'TCH-1001',
        ),
        isTrue,
      );
      signIn(
        username: 'sd.approver',
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.sectionDirector],
      );
      expect(
        data.approveSubjectGrade(
          studentName: student,
          className: className,
          subject: subject,
          reviewerId: 'SD-1',
          reviewerName: 'Section Director',
          reviewerRole: AuthService.roleTeacher,
        ),
        isTrue,
      );

      expect(
        data.updateTermReportCard(
          studentName: student,
          className: className,
          homeroomComment: 'Excellent effort this term.',
          principalComment: 'Promoted with distinction.',
        ),
        isTrue,
      );
      expect(
        data.getGradeReportForStudent(student)!.homeroomComment,
        'Excellent effort this term.',
      );
      expect(data.getGradeReportForStudent(student)!.reportCardPublished, isFalse);

      AuthService.currentUser = RegisteredUser(
        username: 'parent',
        password: 'x',
        roleKey: AuthService.roleParent,
        schoolId: schoolId,
        fullName: 'Mr. Bekele',
        linkedStudentIds: const ['STU-1001'],
      );
      final hidden = data.getGradeReportsForParent().firstWhere(
            (r) => r.studentName == student,
          );
      expect(hidden.homeroomComment, isNull);
      expect(hidden.reportCardPublished, isFalse);
      expect(hidden.subjects, isNotEmpty);

      signIn(
        username: 'sd.approver',
        roleKey: AuthService.roleTeacher,
        staffRoles: const [StaffRoles.sectionDirector],
      );
      expect(
        MarkbookService.instance.publishReportCard(
          studentName: student,
          className: className,
          homeroomComment: 'Excellent effort this term.',
          principalComment: 'Promoted with distinction.',
        ),
        isTrue,
      );

      AuthService.currentUser = RegisteredUser(
        username: 'parent',
        password: 'x',
        roleKey: AuthService.roleParent,
        schoolId: schoolId,
        fullName: 'Mr. Bekele',
        linkedStudentIds: const ['STU-1001'],
      );
      final published = data.getGradeReportsForParent().firstWhere(
            (r) => r.studentName == student,
          );
      expect(published.reportCardPublished, isTrue);
      expect(published.homeroomComment, 'Excellent effort this term.');
    });
  });

  test('markbook and report cards ride the examinations module', () {
    AuthService.currentUser = RegisteredUser(
      username: 'vp.markbook',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(ModuleAccess.canView('markbook'), isTrue);
    expect(ModuleAccess.canManage('markbook'), isTrue);
    expect(ModuleAccess.canView('report_cards'), isTrue);
    expect(ModuleAccess.normalize('markbook'), 'examinations');
    expect(ModuleAccess.normalize('report_cards'), 'examinations');
    expect(AppCollections.gradeReports, 'grade_reports');

    AuthService.currentUser = RegisteredUser(
      username: 'owner.markbook',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('markbook'));
    expect(ids, contains('report_cards'));
    AuthService.currentUser = null;
  });
}
