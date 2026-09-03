import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class ExamPersistenceService {
  ExamPersistenceService._();
  static final instance = ExamPersistenceService._();

  static const _questionsKey = 'exam_questions_v1';
  static const _papersKey = 'exam_papers_v1';
  static const _attemptsKey = 'exam_attempts_v1';

  Future<void> loadIntoService() async {
    final questions = <ExamQuestion>[];
    for (final map in await LocalJsonStore.readList(_questionsKey)) {
      try {
        questions.add(ExamQuestion.fromMap(map));
      } catch (_) {}
    }
    final papers = <ExamPaper>[];
    for (final map in await LocalJsonStore.readList(_papersKey)) {
      try {
        papers.add(ExamPaper.fromMap(map));
      } catch (_) {}
    }
    final attempts = <ExamAttempt>[];
    for (final map in await LocalJsonStore.readList(_attemptsKey)) {
      try {
        attempts.add(ExamAttempt.fromMap(map));
      } catch (_) {}
    }
    ExamService.instance.applyPersistedData(
      questions: questions,
      papers: papers,
      attempts: attempts,
    );
  }

  Future<void> saveFromService({bool pushCloud = true}) async {
    await LocalJsonStore.writeList(
      _questionsKey,
      ExamService.instance.questionMaps(),
    );
    await LocalJsonStore.writeList(
      _papersKey,
      ExamService.instance.paperMaps(),
    );
    await LocalJsonStore.writeList(
      _attemptsKey,
      ExamService.instance.attemptMaps(),
    );
    if (pushCloud) {
      await CloudAppStore.instance.pushAllExamBank();
    }
  }
}
