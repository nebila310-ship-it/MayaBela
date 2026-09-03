import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

/// Teacher dashboard: papers for my classes and a scoring queue.
class TeacherExamsScreen extends StatefulWidget {
  const TeacherExamsScreen({super.key});

  @override
  State<TeacherExamsScreen> createState() => _TeacherExamsScreenState();
}

class _TeacherExamsScreenState extends State<TeacherExamsScreen> {
  final _exams = ExamService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;

  List<String> get _classOptions =>
      _access.myClasses.map((a) => a.className).toSet().toList()..sort();

  @override
  void initState() {
    super.initState();
    _exams.ensureLoaded();
    if (_classOptions.isNotEmpty) _selectedClass = _classOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    const accent = TeacherTheme.primaryDark;
    return ListenableBuilder(
      listenable: Listenable.merge([_exams, AppLocale.instance]),
      builder: (context, _) {
        final className = _selectedClass;
        final papers = className == null
            ? const <ExamPaper>[]
            : _exams
                .papersForSchool()
                .where((p) => p.className == className)
                .toList();
        final queue = _exams
            .scoringQueue()
            .where((a) => className == null || a.className == className)
            .toList();
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('exams')),
          ),
          body: Column(
            children: [
              if (_classOptions.isNotEmpty)
                ClassPickerBar(
                  label: AppLocale.instance.strings.className,
                  options: _classOptions,
                  selected: _selectedClass,
                  accent: accent,
                  onSelected: (value) => setState(() => _selectedClass = value),
                )
              else
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No classes assigned. Exam papers are created in Exam bank & papers.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (_classOptions.isNotEmpty)
                Expanded(
                  child: ListView(
                    padding: listPagePadding(context),
                    children: [
                      Text(
                        'Score written answers, then push the percent into the '
                        'markbook category on the paper. Approval is unchanged.',
                        style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Papers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (papers.isEmpty)
                        const Text('No exam papers for this class yet.')
                      else
                        for (final paper in papers)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(paper.title),
                              subtitle: Text(
                                '${paper.subject} · ${paper.status.name} · '
                                '${paper.markbookCategoryId} · '
                                '${_exams.attemptsForPaper(paper.id).length} attempts',
                              ),
                              trailing: paper.status == ExamPaperStatus.published
                                  ? TextButton(
                                      onPressed: () => _exams.setPaperStatus(
                                        paper.id,
                                        ExamPaperStatus.closed,
                                      ),
                                      child: const Text('Close'),
                                    )
                                  : paper.status == ExamPaperStatus.draft
                                      ? TextButton(
                                          onPressed: () => _exams.setPaperStatus(
                                            paper.id,
                                            ExamPaperStatus.published,
                                          ),
                                          child: const Text('Publish'),
                                        )
                                      : null,
                            ),
                          ),
                      const SizedBox(height: 16),
                      Text(
                        'Needs scoring',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (queue.isEmpty)
                        const Text('No written answers waiting.')
                      else
                        for (final attempt in queue)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(attempt.studentName),
                              subtitle: Text(
                                _exams.paperById(attempt.paperId)?.title ??
                                    attempt.paperId,
                              ),
                              trailing: TextButton(
                                onPressed: () => _score(attempt),
                                child: const Text('Score'),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _score(ExamAttempt attempt) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _TeacherScoreDialog(attemptId: attempt.id),
    );
  }
}

class _TeacherScoreDialog extends StatefulWidget {
  const _TeacherScoreDialog({required this.attemptId});

  final String attemptId;

  @override
  State<_TeacherScoreDialog> createState() => _TeacherScoreDialogState();
}

class _TeacherScoreDialogState extends State<_TeacherScoreDialog> {
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ExamAttempt? get _attempt =>
      ExamService.instance.attemptById(widget.attemptId);

  TextEditingController _ctrl(ExamAnswer answer) {
    return _controllers.putIfAbsent(
      answer.questionId,
      () => TextEditingController(
        text: answer.pointsAwarded == null
            ? ''
            : answer.pointsAwarded!.toStringAsFixed(0),
      ),
    );
  }

  Future<void> _save() async {
    final attempt = _attempt;
    if (attempt == null) return;
    final paper = ExamService.instance.paperById(attempt.paperId);
    final questions = paper == null
        ? const <ExamQuestion>[]
        : ExamService.instance.questionsOnPaper(paper);
    for (final q in questions) {
      if (q.isMcq) continue;
      final raw = _ctrl(
        attempt.answers.cast<ExamAnswer?>().firstWhere(
              (a) => a?.questionId == q.id,
              orElse: () => ExamAnswer(questionId: q.id),
            )!,
      ).text.trim();
      if (raw.isEmpty) continue;
      final points = double.tryParse(raw);
      if (points == null) continue;
      await ExamService.instance.awardPoints(
        attemptId: attempt.id,
        questionId: q.id,
        points: points.clamp(0, q.points),
      );
    }
    final scored = ExamService.instance.attemptById(attempt.id);
    if (scored?.status == ExamAttemptStatus.scored) {
      ExamService.instance.pushAttemptToMarkbook(attempt.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    if (attempt == null) {
      return const AlertDialog(content: Text('Attempt not found.'));
    }
    final paper = ExamService.instance.paperById(attempt.paperId);
    final questions = paper == null
        ? const <ExamQuestion>[]
        : ExamService.instance.questionsOnPaper(paper);
    return AlertDialog(
      title: Text('Score ${attempt.studentName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final q in questions) ...[
                Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  q.isMcq
                      ? 'MCQ awarded ${attempt.answers.cast<ExamAnswer?>().firstWhere((a) => a?.questionId == q.id, orElse: () => null)?.pointsAwarded ?? 0}'
                      : (attempt.answers
                              .cast<ExamAnswer?>()
                              .firstWhere(
                                (a) => a?.questionId == q.id,
                                orElse: () => null,
                              )
                              ?.text ??
                          '—'),
                ),
                if (!q.isMcq)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: TextField(
                      controller: _ctrl(
                        attempt.answers.cast<ExamAnswer?>().firstWhere(
                              (a) => a?.questionId == q.id,
                              orElse: () => ExamAnswer(questionId: q.id),
                            )!,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Points / ${q.points.toStringAsFixed(0)}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
