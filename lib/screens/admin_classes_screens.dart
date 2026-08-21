import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/admin_people_screens.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/section_teacher_assignment_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_classes_ui.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/section_teacher_assign_dialogs.dart';
import 'package:mayabela/web_erp/widgets/web_erp_related_tools.dart';

/// Admin: Classes → Grades → Sections → roster.
class AdminGradesScreen extends StatelessWidget {
  const AdminGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grades = ClassStructureService.instance.gradesForSchool();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return AdminClassesPage(
          appBar: AdminClassesAppBar(
            title: s.dashboardTitle('classes', roleKey: 'admin'),
            subtitle: s.allClasses,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: WebErpRelatedToolsCard(
                  tools: [
                    WebErpRelatedTool(
                      routeId: 'timetable',
                      label: s.timetableAdminTitle,
                      icon: Icons.calendar_view_week,
                      subtitle: 'Homeroom class schedules',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: grades.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            s.noStudentsInSection,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: listPagePadding(context),
                        itemCount: grades.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final grade = grades[index];
                          final sectionCount = ClassStructureService.instance
                              .sectionsForGrade(grade)
                              .length;
                          return AdminGradeCard(
                            grade: grade,
                            sectionCount: sectionCount,
                            sectionLabel: s.section,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminSectionsScreen(grade: grade),
                                ),
                              );
                            },
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
}

class AdminSectionsScreen extends StatefulWidget {
  const AdminSectionsScreen({super.key, required this.grade});

  final String grade;

  @override
  State<AdminSectionsScreen> createState() => _AdminSectionsScreenState();
}

class _AdminSectionsScreenState extends State<AdminSectionsScreen> {
  Future<void> _addSection() async {
    final s = AppLocale.instance.strings;
    final controller = TextEditingController();
    final ok = await showAdminFormDialog(
      context: context,
      title: s.addSection,
      subtitle: widget.grade,
      accent: AdminClassesPalette.primary,
      icon: Icons.grid_view_rounded,
      canSave: (_) => controller.text.trim().isNotEmpty,
      builder: (ctx, setDialogState) {
        return TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: s.section,
            hintText: 'A',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setDialogState(() {}),
        );
      },
    );
    final label = controller.text.trim();
    controller.dispose();
    if (ok != true || label.isEmpty || !mounted) return;

    final added = await ClassStructureService.instance.addSectionForGrade(
      widget.grade,
      label,
    );
    if (!mounted) return;
    if (added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.sectionAdded),
          backgroundColor: Colors.green.shade700,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final structure = ClassStructureService.instance;
    final sections = structure.sectionsForGrade(widget.grade);
    final canManage = ModuleAccess.canManage('academic');

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return AdminClassesPage(
          appBar: AdminClassesAppBar(
            title: widget.grade,
            subtitle: s.allClasses,
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add),
                  label: Text(s.addSection),
                )
              : null,
          body: sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      s.noSectionsYetAdmin,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: listPagePadding(context),
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    final className =
                        structure.classNameFor(widget.grade, section);
                    final students =
                        structure.studentsInSection(widget.grade, section);
                    final teachers =
                        structure.teachersForSection(widget.grade, section);
                    final homeroomName = SchoolDataService.instance
                        .homeroomTeacherNameForClass(className);
                    return AdminSectionCard(
                      section: section,
                      className: className,
                      studentCount: students.length,
                      teacherCount: teachers.length,
                      studentsLabel: s.studentsInClass(students.length),
                      teachersLabel:
                          '${teachers.length} ${s.teachersTab.toLowerCase()}',
                      homeroomName: homeroomName,
                      homeroomLabel:
                          homeroomName != null ? s.homeroomTeacher : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminSectionDetailScreen(
                              grade: widget.grade,
                              section: section,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

class AdminSectionDetailScreen extends StatefulWidget {
  const AdminSectionDetailScreen({
    super.key,
    required this.grade,
    required this.section,
  });

  final String grade;
  final String section;

  @override
  State<AdminSectionDetailScreen> createState() =>
      _AdminSectionDetailScreenState();
}

class _AdminSectionDetailScreenState extends State<AdminSectionDetailScreen> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  List<String> _subjectsForClass(AdminTeacherRecord teacher, String className) {
    final names = teacher.classAssignments
        .where((a) => a.className == className)
        .expand((a) => a.subjectNames)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (names.isNotEmpty) return names;
    return teacher.subjects
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _assignHomeroom(String className, {String? currentId}) async {
    await showAssignHomeroomTeacherDialog(
      context: context,
      className: className,
      currentTeacherId: currentId,
    );
    _refresh();
  }

  Future<void> _assignSubject(
    String className, {
    String? teacherId,
    List<String> subjects = const [],
  }) async {
    await showAssignSubjectTeacherDialog(
      context: context,
      className: className,
      teacherId: teacherId,
      initialSubjects: subjects,
    );
    _refresh();
  }

  Future<void> _removeFromClass({
    required String className,
    required String teacherId,
    required String teacherName,
  }) async {
    final s = AppLocale.instance.strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete),
        content: Text('Remove $teacherName from $className?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await SectionTeacherAssignmentService.instance.removeTeacherFromClass(
      className: className,
      teacherId: teacherId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.teacherUpdated),
        backgroundColor: Colors.green.shade700,
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final structure = ClassStructureService.instance;
    final className = structure.classNameFor(widget.grade, widget.section);
    final students = structure.studentsInSection(widget.grade, widget.section);
    final teachers = structure.teachersForSection(widget.grade, widget.section);
    final homeroomTeachers = teachers.where((t) => t.isHomeroom).toList();
    final otherTeachers = teachers.where((t) => !t.isHomeroom).toList();
    final homeroomName =
        SchoolDataService.instance.homeroomTeacherNameForClass(className);
    final homeroomId =
        SchoolDataService.instance.homeroomTeacherIdForClass(className);
    final canAssign = ModuleAccess.canAssignTeachers;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return AdminClassesPage(
          appBar: AdminClassesAppBar(title: className),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              AdminSectionHero(
                className: className,
                grade: widget.grade,
                section: widget.section,
                studentCount: students.length,
                teacherCount: teachers.length,
                studentsLabel: s.studentsInClass(students.length),
                teachersLabel:
                    '${teachers.length} ${s.teachersTab.toLowerCase()}',
              ),
              const SizedBox(height: 16),
              if (homeroomTeachers.isNotEmpty || homeroomName != null)
                _HomeroomBanner(
                  name: homeroomTeachers.isNotEmpty
                      ? homeroomTeachers.first.teacher.fullName
                      : homeroomName!,
                  onTap: homeroomTeachers.isNotEmpty
                      ? () => _openTeacher(
                            context,
                            homeroomTeachers.first.teacher.teacherId,
                          )
                      : null,
                  onEdit: canAssign
                      ? () => _assignHomeroom(
                            className,
                            currentId: homeroomTeachers.isNotEmpty
                                ? homeroomTeachers.first.teacher.teacherId
                                : homeroomId,
                          )
                      : null,
                  onClear: canAssign &&
                          (homeroomTeachers.isNotEmpty ||
                              (homeroomId != null && homeroomId.isNotEmpty))
                      ? () => _removeFromClass(
                            className: className,
                            teacherId: homeroomTeachers.isNotEmpty
                                ? homeroomTeachers.first.teacher.teacherId
                                : homeroomId!,
                            teacherName: homeroomTeachers.isNotEmpty
                                ? homeroomTeachers.first.teacher.fullName
                                : homeroomName!,
                          )
                      : null,
                )
              else if (canAssign)
                OutlinedButton.icon(
                  onPressed: () => _assignHomeroom(className),
                  icon: const Icon(Icons.home_work_outlined),
                  label: Text(s.homeroomTeacher),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AdminClassesSectionHeader(
                      title: s.sectionTeachers,
                      icon: Icons.school_outlined,
                      count: otherTeachers.length,
                    ),
                  ),
                  if (canAssign)
                    FilledButton.tonalIcon(
                      onPressed: () => _assignSubject(className),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(s.subjectTeacher),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (otherTeachers.isEmpty)
                Text(
                  s.noTeachersInSection,
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...otherTeachers.map((info) {
                  final subjects = _subjectsForClass(info.teacher, className);
                  final subtitle = subjects.isEmpty
                      ? s.subjectTeacher
                      : '${s.subjectTeacher} · ${subjects.join(', ')}';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminClassesPersonTile(
                        name: info.teacher.fullName,
                        subtitle: subtitle,
                        icon: Icons.school_outlined,
                        color: Colors.indigo,
                        onTap: () =>
                            _openTeacher(context, info.teacher.teacherId),
                      ),
                      if (canAssign)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => _assignSubject(
                                  className,
                                  teacherId: info.teacher.teacherId,
                                  subjects: subjects,
                                ),
                                child: Text(s.edit),
                              ),
                              TextButton(
                                onPressed: () => _removeFromClass(
                                  className: className,
                                  teacherId: info.teacher.teacherId,
                                  teacherName: info.teacher.fullName,
                                ),
                                child: Text(s.delete),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                }),
              const SizedBox(height: 24),
              AdminClassesSectionHeader(
                title: s.sectionStudents,
                icon: Icons.groups_outlined,
                count: students.length,
              ),
              const SizedBox(height: 12),
              if (students.isEmpty)
                Text(
                  s.noStudentsInSection,
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...students.map(
                  (student) => AdminClassesPersonTile(
                    name: student.fullName,
                    subtitle: student.studentId,
                    icon: Icons.person_outline,
                    color: Colors.blue,
                    onTap: () => _openStudent(context, student.studentId),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openStudent(BuildContext context, String studentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminStudentProfileScreen(studentId: studentId),
      ),
    ).then((_) => _refresh());
  }

  void _openTeacher(BuildContext context, String teacherId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminTeacherProfileScreen(teacherId: teacherId),
      ),
    ).then((_) => _refresh());
  }
}

class _HomeroomBanner extends StatelessWidget {
  const _HomeroomBanner({
    required this.name,
    this.onTap,
    this.onEdit,
    this.onClear,
  });

  final String name;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade50,
                Colors.green.shade100.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.home_work_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.homeroomTeacher,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: s.edit,
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Colors.green.shade800,
                    ),
                  ),
                if (onClear != null)
                  IconButton(
                    tooltip: s.delete,
                    onPressed: onClear,
                    icon: Icon(Icons.clear, color: Colors.green.shade800),
                  ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: Colors.green.shade700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
