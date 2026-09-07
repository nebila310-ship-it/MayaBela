import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_profile_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';
import 'package:mayabela/widgets/course_attachment_picker.dart';

/// Student portal: sit published papers for this class.
class StudentExamScreen extends StatefulWidget {
  const StudentExamScreen({super.key});

  @override
  State<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends State<StudentExamScreen> {
  final _exams = ExamService.instance;

  String get _studentName {
    final profile = StudentProfileService.profileForCurrentUser();
    if (profile != null && profile.fullName.trim().isNotEmpty) {
      return profile.fullName.trim();
    }
    final children = SchoolDataService.instance.getChildren();
    if (children.isNotEmpty) return children.first.name;
    return AuthService.currentUser?.fullName ??
        AuthService.currentUser?.username ??
        '';
  }

  String get _className {
    final profile = StudentProfileService.profileForCurrentUser();
    if (profile != null && profile.className.trim().isNotEmpty) {
      return profile.className.trim();
    }
    final children = SchoolDataService.instance.getChildren();
    if (children.isNotEmpty) return children.first.className;
    return '';
  }

  String? get _studentId =>
      StudentProfileService.profileForCurrentUser()?.studentId ??
      AuthService.currentUser?.linkedStudentId;

  @override
  void initState() {
    super.initState();
    _exams.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00695C);
    return ListenableBuilder(
      listenable: Listenable.merge([_exams, AppLocale.instance]),
      builder: (context, _) {
        final className = _className;
        final papers = className.isEmpty
            ? const <ExamPaper>[]
            : _exams.openPapersForClass(className);
        final mine = _exams.attempts
            .where(
              (a) =>
                  a.studentName == _studentName ||
                  (a.studentId != null && a.studentId == _studentId),
            )
            .toList();
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('exams')),
          ),
          body: className.isEmpty
              ? const Center(child: Text('Class not found for this student.'))
              : ListView(
                  padding: listPagePadding(context),
                  children: [
                    Text(
                      'Open papers for $className. Multiple-choice is scored '
                      'when you submit. Short and essay answers wait for a teacher.',
                      style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    if (papers.isEmpty && mine.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Center(child: Text('No exams are open right now.')),
                      ),
                    for (final paper in papers)
                      _paperTile(paper, mine, accent),
                    if (mine.any(
                      (a) => papers.every((p) => p.id != a.paperId),
                    )) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Earlier attempts',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      for (final attempt in mine)
                        if (papers.every((p) => p.id != attempt.paperId))
                          _attemptOnlyTile(attempt),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _paperTile(
    ExamPaper paper,
    List<ExamAttempt> mine,
    Color accent,
  ) {
    final attempt = mine.cast<ExamAttempt?>().firstWhere(
          (a) => a?.paperId == paper.id,
          orElse: () => null,
        );
    final status = attempt == null
        ? 'Not started'
        : attempt.status == ExamAttemptStatus.inProgress
            ? 'In progress'
            : attempt.status == ExamAttemptStatus.scored
                ? 'Scored ${attempt.percent.toStringAsFixed(0)}%'
                : 'Submitted — waiting for teacher';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.quiz_outlined, color: accent),
        title: Text(paper.title),
        subtitle: Text('${paper.subject} · ${_categoryLabel(paper.markbookCategoryId)} · $status'),
        trailing: TextButton(
          onPressed: () => _openPaper(paper, attempt),
          child: Text(
            attempt == null
                ? 'Start'
                : attempt.status == ExamAttemptStatus.inProgress
                    ? 'Continue'
                    : 'View',
          ),
        ),
      ),
    );
  }

  Widget _attemptOnlyTile(ExamAttempt attempt) {
    final paper = _exams.paperById(attempt.paperId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(paper?.title ?? attempt.paperId),
        subtitle: Text(
          '${attempt.status.name} · ${attempt.percent.toStringAsFixed(0)}%',
        ),
      ),
    );
  }

  Future<void> _openPaper(ExamPaper paper, ExamAttempt? existing) async {
    final attempt = existing ??
        await _exams.startAttempt(
          paperId: paper.id,
          studentName: _studentName,
          studentId: _studentId,
          className: _className,
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudentAttemptPage(attemptId: attempt.id),
      ),
    );
  }

  static String _categoryLabel(String id) => switch (id) {
        'quiz' => 'Quiz',
        'midterm' => 'Midterm',
        'final' => 'Final',
        _ => id,
      };
}

class _StudentAttemptPage extends StatefulWidget {
  const _StudentAttemptPage({required this.attemptId});

  final String attemptId;

  @override
  State<_StudentAttemptPage> createState() => _StudentAttemptPageState();
}

class _StudentAttemptPageState extends State<_StudentAttemptPage> {
  final _text = <String, TextEditingController>{};
  var _saving = false;

  ExamAttempt? get _attempt =>
      ExamService.instance.attemptById(widget.attemptId);

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String questionId, String? seed) {
    return _text.putIfAbsent(
      questionId,
      () => TextEditingController(text: seed ?? ''),
    );
  }

  List<ExamAnswer> _collect(ExamPaper paper, ExamAttempt attempt) {
    final questions = ExamService.instance.questionsOnPaper(paper);
    return [
      for (final q in questions)
        ExamAnswer(
          questionId: q.id,
          choiceId: attempt.answers
              .cast<ExamAnswer?>()
              .firstWhere((a) => a?.questionId == q.id, orElse: () => null)
              ?.choiceId,
          text: q.isMcq ? null : _ctrl(q.id, null).text.trim(),
          pointsAwarded: attempt.answers
              .cast<ExamAnswer?>()
              .firstWhere((a) => a?.questionId == q.id, orElse: () => null)
              ?.pointsAwarded,
        ),
    ];
  }

  Future<void> _save({required bool submit}) async {
    final attempt = _attempt;
    final paper =
        attempt == null ? null : ExamService.instance.paperById(attempt.paperId);
    if (attempt == null || paper == null || _saving) return;
    if (attempt.status != ExamAttemptStatus.inProgress) return;
    setState(() => _saving = true);
    await ExamService.instance.saveAnswers(
      attempt.id,
      _collect(paper, attempt),
    );
    if (submit) {
      await ExamService.instance.submitAttempt(attempt.id);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (submit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam submitted.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ExamService.instance,
      builder: (context, _) {
        final attempt = _attempt;
        final paper = attempt == null
            ? null
            : ExamService.instance.paperById(attempt.paperId);
        if (attempt == null || paper == null) {
          return const Scaffold(body: Center(child: Text('Exam not found.')));
        }
        final questions = ExamService.instance.questionsOnPaper(paper);
        final locked = attempt.status != ExamAttemptStatus.inProgress;
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: const Color(0xFF00695C),
            title: Text(paper.title),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Text(
                '${paper.subject} · ${questions.length} questions',
                style: TextStyle(color: Colors.grey.shade800),
              ),
              if (paper.attachmentPaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                CourseAttachmentPicker(
                  paths: paper.attachmentPaths,
                  subdir: 'exam_paper_attachments',
                  canEdit: false,
                  allowShareDownload: true,
                  sectionTitle: 'Paper files',
                ),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < questions.length; i++)
                _questionCard(questions[i], attempt, i + 1, locked),
              const SizedBox(height: 16),
              if (!locked)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : () => _save(submit: false),
                      child: const Text('Save draft'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(submit: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: TeacherTheme.primaryDark,
                      ),
                      child: const Text('Submit exam'),
                    ),
                  ],
                )
              else
                Text(
                  attempt.status == ExamAttemptStatus.scored
                      ? 'Submitted and scored: ${attempt.percent.toStringAsFixed(1)}%'
                      : 'Submitted. Your teacher will score written answers.',
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _questionCard(
    ExamQuestion question,
    ExamAttempt attempt,
    int number,
    bool locked,
  ) {
    final answer = attempt.answers.cast<ExamAnswer?>().firstWhere(
          (a) => a?.questionId == question.id,
          orElse: () => null,
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. ${question.prompt}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (question.attachmentPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              CourseAttachmentPicker(
                paths: question.attachmentPaths,
                subdir: 'exam_question_attachments',
                canEdit: false,
                allowShareDownload: true,
                sectionTitle: 'Question files',
              ),
            ],
            const SizedBox(height: 8),
            if (question.isMcq)
              for (final choice in question.choices)
                RadioListTile<String>(
                  dense: true,
                  value: choice.id,
                  groupValue: answer?.choiceId,
                  onChanged: locked
                      ? null
                      : (v) async {
                          final paper = ExamService.instance
                              .paperById(attempt.paperId);
                          if (paper == null) return;
                          final next = [
                            for (final a in _collect(paper, attempt))
                              a.questionId == question.id
                                  ? ExamAnswer(
                                      questionId: question.id,
                                      choiceId: v,
                                    )
                                  : a,
                          ];
                          await ExamService.instance.saveAnswers(attempt.id, next);
                        },
                  title: Text(choice.text),
                )
            else
              TextField(
                controller: _ctrl(question.id, answer?.text),
                enabled: !locked,
                maxLines: question.type == ExamQuestionType.essay ? 6 : 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Write your answer',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
