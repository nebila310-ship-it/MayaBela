import 'package:flutter/material.dart';

import 'package:mayabela/constants/school_subjects.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/pages/web_lesson_plans_page.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';

/// Teacher dashboard: weekly plans for my classes.
class TeacherLessonPlansScreen extends StatefulWidget {
  const TeacherLessonPlansScreen({super.key});

  @override
  State<TeacherLessonPlansScreen> createState() =>
      _TeacherLessonPlansScreenState();
}

class _TeacherLessonPlansScreenState extends State<TeacherLessonPlansScreen> {
  final _plans = LessonPlanService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;

  List<String> get _classOptions =>
      _access.myClasses.map((a) => a.className).toSet().toList()..sort();

  List<String> get _subjects {
    final fromSlots = _access.myClasses
        .map((a) => a.subject)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toSet();
    final list = {...fromSlots, ...SchoolSubjects.all}.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    _plans.ensureLoaded();
    if (_classOptions.isNotEmpty) _selectedClass = _classOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    const accent = TeacherTheme.primaryDark;
    return ListenableBuilder(
      listenable: Listenable.merge([_plans, AppLocale.instance]),
      builder: (context, _) {
        final className = _selectedClass;
        final items = className == null
            ? const <LessonPlan>[]
            : _plans.forClass(className);
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('lesson_plans')),
          ),
          floatingActionButton: className == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openEditor(),
                  backgroundColor: accent,
                  icon: const Icon(Icons.add),
                  label: const Text('New plan'),
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
                        'No classes assigned.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (_classOptions.isNotEmpty)
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('No lesson plans for this class.'))
                      : ListView.builder(
                          padding: listPagePadding(context),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final plan = items[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(plan.title),
                                subtitle: Text(
                                  '${plan.subject} · ${plan.isPublished ? 'Published' : 'Draft'}',
                                ),
                                trailing: TextButton(
                                  onPressed: () => _plans.setStatus(
                                    plan.id,
                                    plan.isPublished
                                        ? LessonPlanStatus.draft
                                        : LessonPlanStatus.published,
                                  ),
                                  child: Text(
                                    plan.isPublished ? 'Unpublish' : 'Publish',
                                  ),
                                ),
                                onTap: () => _openEditor(plan),
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor([LessonPlan? plan]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => LessonPlanEditorDialog(
        existing: plan,
        classes: _classOptions,
        subjects: _subjects,
      ),
    );
  }
}
