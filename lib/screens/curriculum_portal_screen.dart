import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_profile_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/pages/web_curriculum_page.dart';

enum CurriculumPortalMode { teacher, student, parent }

/// Teacher / student / parent view of published curriculum maps + feedback.
class CurriculumPortalScreen extends StatefulWidget {
  const CurriculumPortalScreen({super.key, required this.mode});

  final CurriculumPortalMode mode;

  @override
  State<CurriculumPortalScreen> createState() => _CurriculumPortalScreenState();
}

class _CurriculumPortalScreenState extends State<CurriculumPortalScreen> {
  final _curriculum = CurriculumService.instance;

  Color get _accent => widget.mode == CurriculumPortalMode.teacher
      ? const Color(0xFF1565C0)
      : const Color(0xFF5D4037);

  String get _className {
    final profile = StudentProfileService.profileForCurrentUser();
    if (profile != null && profile.className.trim().isNotEmpty) {
      return profile.className.trim();
    }
    final children = SchoolDataService.instance.getChildren();
    if (children.isNotEmpty) return children.first.className;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _curriculum.ensureLoaded();
    LessonPlanService.instance.ensureLoaded();
    ExamService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_curriculum, AppLocale.instance]),
      builder: (context, _) {
        final className = _className;
        final units = widget.mode == CurriculumPortalMode.teacher
            ? _curriculum.unitsForSchool()
            : className.isEmpty
                ? _curriculum.unitsForSchool().where((u) => u.isPublished).toList()
                : _curriculum.publishedForClass(className);
        final evals = widget.mode == CurriculumPortalMode.teacher
            ? _curriculum.evaluationsForSchool()
            : const <TeacherEvaluation>[];
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: _accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('curriculum')),
          ),
          floatingActionButton: units.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showCurriculumFeedbackDialog(context),
                  backgroundColor: _accent,
                  icon: const Icon(Icons.comment_outlined),
                  label: const Text('Feedback'),
                ),
          body: units.isEmpty && evals.isEmpty
              ? const Center(child: Text('No published curriculum units yet.'))
              : ListView(
                  padding: listPagePadding(context),
                  children: [
                    for (final unit in units) _unitCard(unit),
                    if (evals.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'My academic evaluations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      for (final item in evals)
                        Card(
                          child: ListTile(
                            title: Text(item.periodLabel),
                            subtitle: Text(
                              'Fidelity ${item.curriculumFidelity}/5 · '
                              'Planning ${item.planningQuality}/5 · '
                              'Alignment ${item.assessmentAlignment}/5',
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _unitCard(CurriculumUnit unit) {
    final plans = [
      for (final id in unit.lessonPlanIds)
        if (LessonPlanService.instance.planById(id) != null)
          LessonPlanService.instance.planById(id)!,
    ];
    final papers = [
      for (final id in unit.examPaperIds)
        if (ExamService.instance.paperById(id) != null)
          ExamService.instance.paperById(id)!,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(unit.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${unit.subject} · ${unit.framework.name}'
              '${unit.standardCodes.isEmpty ? '' : ' · ${unit.standardCodes.join(', ')}'}'
              '${unit.isPublished ? '' : ' · draft'}',
            ),
            if (unit.objectives.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(unit.objectives),
            ],
            if (plans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Lesson plans: ${plans.map((p) => p.title).join(', ')}'),
            ],
            if (papers.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Assessments: ${papers.map((p) => p.title).join(', ')}'),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showCurriculumFeedbackDialog(
                  context,
                  unitId: unit.id,
                ),
                child: const Text('Comment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherCurriculumScreen extends StatelessWidget {
  const TeacherCurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CurriculumPortalScreen(mode: CurriculumPortalMode.teacher);
}

class StudentCurriculumScreen extends StatelessWidget {
  const StudentCurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CurriculumPortalScreen(mode: CurriculumPortalMode.student);
}

class ParentCurriculumScreen extends StatelessWidget {
  const ParentCurriculumScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const CurriculumPortalScreen(mode: CurriculumPortalMode.parent);
}
