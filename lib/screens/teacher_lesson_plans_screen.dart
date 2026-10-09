import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/pages/web_lesson_plans_page.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/lesson_plan_view_card.dart';

/// Teacher dashboard: weekly plans for my classes.
class TeacherLessonPlansScreen extends StatefulWidget {
  const TeacherLessonPlansScreen({super.key, this.initialClass});

  final String? initialClass;

  @override
  State<TeacherLessonPlansScreen> createState() =>
      _TeacherLessonPlansScreenState();
}

class _TeacherLessonPlansScreenState extends State<TeacherLessonPlansScreen> {
  final _plans = LessonPlanService.instance;
  final _access = TeacherAccessService.instance;
  String? _selectedClass;

  List<String> get _classOptions {
    final names = <String>{
      ..._access.myClasses.map((a) => a.className),
      ...AuthService.accessClassNamesForSync(),
    };
    return names.where((name) => name.trim().isNotEmpty).toList()..sort();
  }

  List<String> _subjectsFor(String className) {
    return _access.teachableSubjects(className);
  }

  @override
  void initState() {
    super.initState();
    _plans.ensureLoaded();
    CurriculumService.instance.ensureLoaded();
    if (widget.initialClass != null &&
        widget.initialClass!.trim().isNotEmpty) {
      _selectedClass = widget.initialClass!.trim();
    } else if (_classOptions.isNotEmpty) {
      _selectedClass = _classOptions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = TeacherTheme.primaryDark;
    return ListenableBuilder(
      listenable: Listenable.merge([_plans, AppLocale.instance]),
      builder: (context, _) {
        final className = _selectedClass;
        final subjects =
            className == null ? const <String>[] : _subjectsFor(className);
        final items = className == null
            ? const <LessonPlan>[]
            : _plans.forClass(className);
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('lesson_plans')),
          ),
          floatingActionButton: className == null || subjects.isEmpty
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    subjects.isEmpty
                        ? 'No subjects are assigned to you in this class, so you cannot prepare a lesson plan here.'
                        : 'Prepare weekly plans for ${subjects.join(', ')} only. Other subjects stay hidden. Submit sends the plan to parents of this class (read-only).',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_classOptions.isNotEmpty)
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            subjects.isEmpty
                                ? 'No assigned subjects for this class.'
                                : 'No lesson plans for your subjects in this class.',
                          ),
                        )
                      : ListView.builder(
                          padding: listPagePadding(context),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final plan = items[i];
                            return LessonPlanViewCard(
                              key: ValueKey(plan.id),
                              plan: plan,
                              accent: accent,
                              initiallyExpanded: items.length == 1,
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    if (plan.isPublished &&
                                        plan.reviewStatus !=
                                            LessonPlanReviewStatus
                                                .changesRequested) {
                                      _plans.setStatus(
                                        plan.id,
                                        LessonPlanStatus.draft,
                                      );
                                      return;
                                    }
                                    _plans.submitForReview(plan.id);
                                  },
                                  child: Text(
                                    plan.reviewStatus ==
                                            LessonPlanReviewStatus
                                                .changesRequested
                                        ? 'Resubmit'
                                        : plan.isPublished
                                            ? 'Unpublish'
                                            : 'Submit',
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _openEditor(plan),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Edit'),
                                ),
                              ],
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
    final className = plan?.className ?? _selectedClass ?? _classOptions.first;
    final subjects = _subjectsFor(className);
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only prepare lesson plans for your assigned subjects.'),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => LessonPlanEditorDialog(
        existing: plan,
        classes: _classOptions,
        subjects: subjects,
        subjectsForClass: _subjectsFor,
      ),
    );
  }
}
