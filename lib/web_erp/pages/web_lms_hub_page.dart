import 'package:flutter/material.dart';

import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/lms_classroom_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/widgets/online_class_link_button.dart';

/// Course hub built from existing lesson plans, homework, materials, and exams.
class WebLmsHubPage extends StatelessWidget {
  const WebLmsHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  void _openSisRoster(BuildContext context, String className) {
    final schoolId = AuthService.activeSchoolId;
    final students = StudentRegistryService.instance.studentsForClass(
      className,
      schoolId: schoolId,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$className SIS roster'),
        content: SizedBox(
          width: 420,
          child: students.isEmpty
              ? const Text(
                  'No registry students in this class. The SIS profile is the '
                  'same student record used by Students — this is not a second roster.',
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final student in students)
                      ListTile(
                        title: Text(student.fullName),
                        subtitle: Text(student.studentId),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          showWebStudentProfileDialog(
                            context,
                            studentId: student.studentId,
                          );
                        },
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final courses = LmsClassroomService.instance.coursesForSchool(schoolId);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Learning Management', style: WebErpTheme.sectionTitle(context)),
        const SizedBox(height: 6),
        Text(
          'Courses are class + subject spaces. Lesson notes, worksheets, and '
          'exams stay in their existing desks — this hub shows them together '
          'and replaces Telegram groups with class discussion.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onNavigate != null) ...[
              FilledButton.tonal(
                onPressed: () => onNavigate!('lesson_plans'),
                child: const Text('Lesson plans'),
              ),
              FilledButton.tonal(
                onPressed: () => onNavigate!('homework'),
                child: const Text('Homework'),
              ),
              FilledButton.tonal(
                onPressed: () => onNavigate!('learning_materials'),
                child: const Text('Materials'),
              ),
              FilledButton.tonal(
                onPressed: () => onNavigate!('exam_bank'),
                child: const Text('Exams'),
              ),
              FilledButton.tonal(
                onPressed: () => onNavigate!('curriculum'),
                child: const Text('Curriculum'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: WebErpTheme.cardDecoration(context),
            child: const Text(
              'No class/subject courses yet. Publish a lesson plan, homework, '
              'material, or exam paper to create one.',
            ),
          )
        else
          for (final course in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DecoratedBox(
                decoration: WebErpTheme.cardDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${course.className} · ${course.subject}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${course.lessonPlans} lesson plans · '
                        '${course.homework} homework · '
                        '${course.materials} materials · '
                        '${course.examPapers} exams',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Engagement: ${course.submittedWorksheets} worksheet'
                        '${course.submittedWorksheets == 1 ? '' : 's'} and '
                        '${course.examAttempts} exam attempt'
                        '${course.examAttempts == 1 ? '' : 's'}'
                        '${course.rosterSize > 0 ? ' · ${course.rosterSize} students' : ''}',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (course.onlinePlan != null)
                            OnlineClassLinkButton(plan: course.onlinePlan!),
                          TextButton.icon(
                            onPressed: () {
                              final id = LmsClassroomService.instance
                                  .ensureClassDiscussion(course.className);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: id,
                                    contactName:
                                        LmsClassroomService.discussionTitle(
                                      course.className,
                                    ),
                                    isGroup: true,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.forum_outlined),
                            label: const Text('Class discussion'),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _openSisRoster(context, course.className),
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('SIS roster'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
