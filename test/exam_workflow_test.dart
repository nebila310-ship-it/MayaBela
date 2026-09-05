import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExamService.resetForTests();
  });

  group('Serialization', () {
    test('question, paper, and attempt round-trip', () {
      final now = DateTime.utc(2026, 9, 3, 8);
      final question = ExamQuestion(
        id: 'Q-0001',
        schoolId: 'TB-001',
        subject: 'Science',
        prompt: 'Water freezes at?',
        type: ExamQuestionType.mcq,
        points: 5,
        choices: const [
          ExamChoice(id: 'A', text: '0°C'),
          ExamChoice(id: 'B', text: '100°C'),
        ],
        correctChoiceId: 'A',
        attachmentPaths: const ['exam_question_attachments/diagram.png'],
        createdAt: now,
        updatedAt: now,
      );
      final paper = ExamPaper(
        id: 'EX-0001',
        schoolId: 'TB-001',
        title: 'Science midterm',
        className: 'Grade 4A',
        subject: 'Science',
        questionIds: const ['Q-0001'],
        markbookCategoryId: 'midterm',
        status: ExamPaperStatus.published,
        attachmentPaths: const ['exam_paper_attachments/cover.pdf'],
        createdAt: now,
        updatedAt: now,
      );
      final attempt = ExamAttempt(
        id: 'AT-0001',
        paperId: 'EX-0001',
        schoolId: 'TB-001',
        studentName: 'Sara Bekele',
        className: 'Grade 4A',
        studentId: 'STU-1001',
        answers: [ExamAnswer(questionId: 'Q-0001', choiceId: 'A', pointsAwarded: 5)],
        maxPoints: 5,
        status: ExamAttemptStatus.scored,
        startedAt: now,
        updatedAt: now,
      );

      expect(ExamQuestion.fromMap(question.toMap()).correctChoiceId, 'A');
      expect(
        ExamQuestion.fromMap(question.toMap()).attachmentPaths,
        ['exam_question_attachments/diagram.png'],
      );
      expect(ExamPaper.fromMap(paper.toMap()).markbookCategoryId, 'midterm');
      expect(
        ExamPaper.fromMap(paper.toMap()).attachmentPaths,
        ['exam_paper_attachments/cover.pdf'],
      );
      expect(ExamPaper.fromMap(paper.toMap()).isOpenAt(now), isTrue);
      expect(ExamAttempt.fromMap(attempt.toMap()).percent, 100);
    });
  });

  group('Workflow', () {
    const schoolId = 'TB-001';
    const student = 'Sara Bekele';
    const className = 'Grade 4A';
    const subject = 'Science';

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

    test('MCQ auto-score pushes into midterm and approval still publishes',
        () async {
      final data = SchoolDataService.instance;
      signIn(username: 'admin.unlock', roleKey: AuthService.roleAdmin);
      data.adminUnlockSubjectGrade(
        studentName: student,
        className: className,
        subject: subject,
        adminId: 'ADM-1',
        adminName: 'Admin',
      );

      signIn(username: 'teacher.sci', roleKey: AuthService.roleTeacher);
      final question = await ExamService.instance.createQuestion(
        subject: subject,
        prompt: 'Plants make food by?',
        type: ExamQuestionType.mcq,
        points: 10,
        choices: const [
          ExamChoice(id: 'A', text: 'Photosynthesis'),
          ExamChoice(id: 'B', text: 'Evaporation'),
        ],
        correctChoiceId: 'A',
        schoolId: schoolId,
      );
      final paper = await ExamService.instance.createPaper(
        title: 'Science midterm paper',
        className: className,
        subject: subject,
        questionIds: [question.id],
        markbookCategoryId: 'midterm',
        schoolId: schoolId,
      );
      await ExamService.instance.setPaperStatus(
        paper.id,
        ExamPaperStatus.published,
      );

      final attempt = await ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: student,
        studentId: 'STU-1001',
        className: className,
        schoolId: schoolId,
      );
      await ExamService.instance.saveAnswers(
        attempt.id,
        [ExamAnswer(questionId: question.id, choiceId: 'A')],
      );
      final submitted = await ExamService.instance.submitAttempt(attempt.id);
      expect(submitted?.status, ExamAttemptStatus.scored);
      expect(submitted?.percent, 100);
      expect(submitted?.scoredBy, 'auto');

      expect(
        ExamService.instance.pushAttemptToMarkbook(
          attempt.id,
          teacherId: 'TCH-1001',
        ),
        isTrue,
      );

      var grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.canTeacherEdit, isTrue);
      expect(grade.hasMarkbook, isTrue);
      final midterm = grade.assessments.firstWhere((m) => m.categoryId == 'midterm');
      expect(midterm.score, 100);
      expect(grade.score, greaterThan(0));

      expect(
        data.submitSubjectGradeForApproval(
          studentName: student,
          className: className,
          subject: subject,
          teacherId: 'TCH-1001',
        ),
        isTrue,
      );
      grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.status, SubjectGradeStatus.pendingApproval);
      expect(grade.isVisibleToParent, isFalse);
      expect(
        ExamService.instance.pushAttemptToMarkbook(attempt.id),
        isFalse,
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
      grade = data
          .getGradeReportForStudent(student)!
          .subjects
          .firstWhere((s) => s.subject == subject);
      expect(grade.isVisibleToParent, isTrue);
    });

    test('short answer stays unscored until a teacher awards points', () async {
      signIn(username: 'teacher.sci', roleKey: AuthService.roleTeacher);
      final question = await ExamService.instance.createQuestion(
        subject: subject,
        prompt: 'Name one planet.',
        type: ExamQuestionType.shortAnswer,
        points: 4,
        schoolId: schoolId,
      );
      final paper = await ExamService.instance.createPaper(
        title: 'Science quiz',
        className: className,
        subject: subject,
        questionIds: [question.id],
        markbookCategoryId: 'quiz',
        schoolId: schoolId,
      );
      final attempt = await ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: student,
        className: className,
        schoolId: schoolId,
      );
      await ExamService.instance.saveAnswers(
        attempt.id,
        [ExamAnswer(questionId: question.id, text: 'Earth')],
      );
      final submitted = await ExamService.instance.submitAttempt(attempt.id);
      expect(submitted?.status, ExamAttemptStatus.submitted);
      expect(submitted?.needsManualScore, isTrue);
      expect(ExamService.instance.pushAttemptToMarkbook(attempt.id), isFalse);

      final scored = await ExamService.instance.awardPoints(
        attemptId: attempt.id,
        questionId: question.id,
        points: 4,
        scoredBy: 'teacher.sci',
      );
      expect(scored?.status, ExamAttemptStatus.scored);
      expect(scored?.percent, 100);
    });
  });

  test('exam bank rides the examinations module and sync lane', () {
    AuthService.currentUser = RegisteredUser(
      username: 'vp.exams',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
    expect(ModuleAccess.canView('exam_bank'), isTrue);
    expect(ModuleAccess.canManage('exam_bank'), isTrue);
    expect(ModuleAccess.normalize('exam_bank'), 'examinations');
    expect(ModuleAccess.normalize('exam_papers'), 'examinations');
    expect(ModuleAccess.normalize('exam_desk'), 'examinations');
    expect(AppCollections.examQuestions, 'exam_questions');
    expect(AppCollections.examPapers, 'exam_papers');
    expect(AppCollections.examAttempts, 'exam_attempts');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll(['exam_questions', 'exam_papers', 'exam_attempts']),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'owner.exams',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('exam_bank'));
    AuthService.currentUser = null;
  });
}
