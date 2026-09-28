import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.sci',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  Future<ExamPaper> _paper({
    ExamKind kind = ExamKind.school,
    ExamSittingMode sitting = ExamSittingMode.online,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return ExamService.instance.createPaper(
      title: 'Science quiz',
      className: 'Grade 4A',
      subject: 'Science',
      questionIds: const ['Q-0001'],
      kind: kind,
      sittingMode: sitting,
      startAt: startAt,
      endAt: endAt,
      schoolId: 'TB-001',
    );
  }

  test('draft, closed, and future windows cannot start a portal sitting',
      () async {
    final paper = await _paper(
      startAt: DateTime.now().add(const Duration(days: 3)),
    );
    expect(
      () => ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: 'Sara Bekele',
      ),
      throwsStateError,
    );

    await ExamService.instance.setPaperStatus(
      paper.id,
      ExamPaperStatus.published,
    );
    expect(
      () => ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: 'Sara Bekele',
      ),
      throwsStateError,
    );

    await ExamService.instance.updatePaper(
      paper.id,
      clearWindow: true,
    );
    final open = await ExamService.instance.startAttempt(
      paperId: paper.id,
      studentName: 'Sara Bekele',
    );
    expect(open.status, ExamAttemptStatus.inProgress);

    await ExamService.instance.setPaperStatus(
      paper.id,
      ExamPaperStatus.closed,
    );
    expect(
      () => ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: 'Kidus Bekele',
      ),
      throwsStateError,
    );
    expect(
      await ExamService.instance.startAttempt(
        paperId: paper.id,
        studentName: 'Sara Bekele',
      ),
      same(open),
    );
  });

  test('duplicatePaper copies a national template as a new draft', () async {
    final source = await _paper(
      kind: ExamKind.national,
      sitting: ExamSittingMode.offline,
    );
    await ExamService.instance.setPaperStatus(
      source.id,
      ExamPaperStatus.published,
    );
    final copy = await ExamService.instance.duplicatePaper(source.id);
    expect(copy.id, isNot(source.id));
    expect(copy.title, 'Science quiz (template)');
    expect(copy.kind, ExamKind.national);
    expect(copy.sittingMode, ExamSittingMode.offline);
    expect(copy.questionIds, ['Q-0001']);
    expect(copy.status, ExamPaperStatus.draft);
    expect(copy.startAt, isNull);
  });

  test('kind filter and historical repository use existing papers', () async {
    final school = await _paper();
    final national = await _paper(kind: ExamKind.national);
    await ExamService.instance.setPaperStatus(
      national.id,
      ExamPaperStatus.closed,
    );

    expect(
      ExamService.instance.papersForKind(ExamKind.national, 'TB-001').map((p) => p.id),
      contains(national.id),
    );
    expect(
      ExamService.instance.papersForKind(ExamKind.school, 'TB-001').map((p) => p.id),
      contains(school.id),
    );
    expect(school.isHistoricalAt(DateTime.now()), isFalse);
    expect(national.isHistoricalAt(DateTime.now()), isTrue);
    expect(
      ExamService.instance.historicalPapersForSchool('TB-001').map((p) => p.id),
      contains(national.id),
    );
  });
}
