import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_profile_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/lesson_plan_view_card.dart';

/// Published weekly plans for the signed-in student or a parent's children.
class StudentLessonPlansScreen extends StatefulWidget {
  const StudentLessonPlansScreen({super.key});

  @override
  State<StudentLessonPlansScreen> createState() =>
      _StudentLessonPlansScreenState();
}

class _StudentLessonPlansScreenState extends State<StudentLessonPlansScreen> {
  final _plans = LessonPlanService.instance;

  List<String> get _classNames {
    final names = <String>{};
    final profile = StudentProfileService.profileForCurrentUser();
    if (profile != null && profile.className.trim().isNotEmpty) {
      names.add(profile.className.trim());
    }
    for (final child in SchoolDataService.instance.getChildren()) {
      final n = child.className.trim();
      if (n.isNotEmpty) names.add(n);
    }
    for (final name in AuthService.accessClassNamesForSync()) {
      final n = name.trim();
      if (n.isNotEmpty) names.add(n);
    }
    return names.toList();
  }

  @override
  void initState() {
    super.initState();
    _plans.ensureLoaded();
    ExamService.instance.ensureLoaded();
    CurriculumService.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5D4037);
    return ListenableBuilder(
      listenable: Listenable.merge([_plans, AppLocale.instance]),
      builder: (context, _) {
        final classNames = _classNames;
        final seen = <String>{};
        final items = <LessonPlan>[];
        for (final name in classNames) {
          for (final plan in _plans.publishedForClass(name)) {
            if (seen.add(plan.id)) items.add(plan);
          }
        }
        if (items.isEmpty && classNames.isEmpty) {
          for (final plan in _plans.forSchool()) {
            if (plan.isPublished && seen.add(plan.id)) items.add(plan);
          }
        }
        items.sort((a, b) => b.weekStart.compareTo(a.weekStart));
        final isParent =
            AuthService.currentUser?.roleKey == AuthService.roleParent;
        final emptyClass = classNames.isEmpty && items.isEmpty;
        final emptyHint = isParent
            ? 'No linked student class yet.'
            : 'Class not found for this student.';
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: accent,
            title: Text(AppLocale.instance.strings.dashboardTitle('lesson_plans')),
          ),
          body: emptyClass
              ? Center(child: Text(emptyHint))
              : items.isEmpty
                  ? Center(
                      child: Text(
                        isParent
                            ? 'No published lesson plans for this class yet.'
                            : 'No published lesson plans yet.',
                      ),
                    )
                  : ListView.builder(
                      padding: listPagePadding(context),
                      itemCount: items.length + (isParent ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (isParent && i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Teachers publish weekly plans for this class. '
                              'You can read them and open worksheets. You cannot edit them.',
                            ),
                          );
                        }
                        final plan = items[isParent ? i - 1 : i];
                        return LessonPlanViewCard(
                          key: ValueKey(plan.id),
                          plan: plan,
                          accent: accent,
                          initiallyExpanded: items.length == 1,
                        );
                      },
                    ),
        );
      },
    );
  }

}
