import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_profile_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

/// Student portal: published weekly plans for this class.
class StudentLessonPlansScreen extends StatefulWidget {
  const StudentLessonPlansScreen({super.key});

  @override
  State<StudentLessonPlansScreen> createState() =>
      _StudentLessonPlansScreenState();
}

class _StudentLessonPlansScreenState extends State<StudentLessonPlansScreen> {
  final _plans = LessonPlanService.instance;

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
    _plans.ensureLoaded();
    ExamService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5D4037);
    return ListenableBuilder(
      listenable: Listenable.merge([_plans, AppLocale.instance]),
      builder: (context, _) {
        final className = _className;
        final items = className.isEmpty
            ? const <LessonPlan>[]
            : _plans.publishedForClass(className);
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('lesson_plans')),
          ),
          body: className.isEmpty
              ? const Center(child: Text('Class not found for this student.'))
              : items.isEmpty
                  ? const Center(child: Text('No published lesson plans yet.'))
                  : ListView.builder(
                      padding: listPagePadding(context),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _card(items[i], accent),
                    ),
        );
      },
    );
  }

  Widget _card(LessonPlan plan, Color accent) {
    final homework = SchoolDataService.instance
        .getHomeworkForClass(plan.className)
        .where((h) => plan.homeworkIds.contains(h.id))
        .toList();
    final papers = [
      for (final id in plan.examPaperIds)
        if (ExamService.instance.paperById(id) != null)
          ExamService.instance.paperById(id)!,
    ];
    final materials = SchoolDataService.instance
        .learningMaterialsSnapshot()
        .where((m) => plan.learningMaterialIds.contains(m.id))
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${plan.subject} · week of ${plan.weekStart.day}/${plan.weekStart.month}',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            if (plan.objectives.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(plan.objectives),
            ],
            if (plan.activities.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.activities),
            ],
            if (homework.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Homework: ${homework.map((h) => h.subject).join(', ')}'),
            ],
            if (papers.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Exams: ${papers.map((p) => p.title).join(', ')}'),
            ],
            if (materials.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Materials: ${materials.map((m) => m.bookName.isEmpty ? m.materialName : m.bookName).join(', ')}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
