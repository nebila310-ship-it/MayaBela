import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExamService.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() => AuthService.currentUser = null);

  void signIn(String username) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: username,
    );
  }

  test('teachers keep a categorized private list and share into the vault', () async {
    signIn('teacher.sci');
    final privateQ = await ExamService.instance.createQuestion(
      subject: 'Science',
      prompt: 'What is H2O?',
      type: ExamQuestionType.shortAnswer,
      category: 'Quiz',
      vaultAccess: ExamVaultAccess.private,
      schoolId: 'TB-001',
    );
    final vaultQ = await ExamService.instance.createQuestion(
      subject: 'Science',
      prompt: 'Name a planet.',
      type: ExamQuestionType.shortAnswer,
      category: 'Midterm',
      vaultAccess: ExamVaultAccess.vault,
      schoolId: 'TB-001',
    );
    final paper = await ExamService.instance.createPaper(
      title: 'Science quiz 1',
      className: 'Grade 4A',
      subject: 'Science',
      questionIds: [vaultQ.id],
      category: 'Quiz',
      vaultAccess: ExamVaultAccess.vault,
      schoolId: 'TB-001',
    );

    expect(ExamService.instance.questionsForTeacher().map((q) => q.id),
        containsAll([privateQ.id, vaultQ.id]));
    expect(ExamService.instance.papersForTeacher().map((p) => p.id), contains(paper.id));
    expect(ExamService.instance.vaultQuestions().map((q) => q.id), contains(vaultQ.id));
    expect(ExamService.instance.vaultQuestions().map((q) => q.id), isNot(contains(privateQ.id)));
    expect(ExamService.instance.bankCategories(mineOnly: true), containsAll(['Quiz', 'Midterm']));

    signIn('teacher.math');
    expect(ExamService.instance.canViewQuestion(privateQ), isFalse);
    expect(ExamService.instance.canViewQuestion(vaultQ), isTrue);
    expect(ExamService.instance.canEditQuestion(vaultQ), isFalse);
    expect(ExamService.instance.questionsForTeacher(), isEmpty);
    expect(
      ExamService.instance.vaultQuestions().map((q) => q.id),
      contains(vaultQ.id),
    );

    final copy = await ExamService.instance.copyQuestionToMyBank(vaultQ.id);
    expect(copy.createdBy, 'teacher.math');
    expect(copy.vaultAccess, ExamVaultAccess.private);
    expect(copy.category, 'Midterm');
    expect(ExamService.instance.questionsForTeacher().map((q) => q.id), contains(copy.id));

    final paperCopy = await ExamService.instance.copyPaperToMyBank(paper.id);
    expect(paperCopy.createdBy, 'teacher.math');
    expect(paperCopy.vaultAccess, ExamVaultAccess.private);
    expect(paperCopy.title, contains('my copy'));
    expect(ExamService.instance.canEditPaper(paper), isFalse);
    expect(ExamService.instance.canEditPaper(paperCopy), isTrue);
  });

  test('parents cannot open the teacher exam vault', () async {
    signIn('teacher.sci');
    final vaultQ = await ExamService.instance.createQuestion(
      subject: 'Science',
      prompt: 'Shared only with teachers',
      type: ExamQuestionType.shortAnswer,
      vaultAccess: ExamVaultAccess.vault,
      schoolId: 'TB-001',
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.one',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(ExamService.instance.canViewQuestion(vaultQ), isFalse);
    expect(ExamService.instance.canViewPaper(
      ExamPaper(
        id: 'EX-HIDE',
        schoolId: 'TB-001',
        title: 'Hidden',
        className: 'Grade 4A',
        subject: 'Science',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vaultAccess: ExamVaultAccess.vault,
        createdBy: 'teacher.sci',
      ),
    ), isFalse);
  });

  test('paper can be saved with an attached file and no bank questions', () async {
    signIn('teacher.sci');
    final paper = await ExamService.instance.createPaper(
      title: 'Grade 8 model paper',
      className: 'Grade 8A',
      subject: 'Science',
      questionIds: const [],
      attachmentPaths: const ['exam_paper_attachments/sample.png'],
      sittingMode: ExamSittingMode.offline,
      schoolId: 'TB-001',
    );
    expect(paper.hasContent, isTrue);
    expect(paper.questionIds, isEmpty);
    expect(paper.attachmentPaths, ['exam_paper_attachments/sample.png']);
  });

  test('question can be a file only', () async {
    signIn('teacher.sci');
    final question = await ExamService.instance.createQuestion(
      subject: 'Science',
      prompt: '  ',
      type: ExamQuestionType.shortAnswer,
      attachmentPaths: const ['exam_question_attachments/q1.png'],
      schoolId: 'TB-001',
    );
    expect(question.prompt, 'Attached question');
    expect(question.displayPrompt, 'Attached question');
    expect(question.attachmentPaths, ['exam_question_attachments/q1.png']);
  });

  test('teacher dashboard includes exams in teaching tools', () {
    registerAllDashboards();
    expect(
      sectionDefinitionsFor(AuthService.roleTeacher).expand((s) => s.entryIds),
      contains('exams'),
    );
    expect(DashboardRegistry.find(AuthService.roleTeacher, 'exams'), isNotNull);
  });
}
