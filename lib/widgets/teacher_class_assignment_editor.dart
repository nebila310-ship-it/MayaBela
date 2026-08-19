import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/subject_multi_picker.dart';

/// One grade/section + role row for teacher class assignments.
class TeacherClassAssignmentEntry {
  TeacherClassAssignmentEntry();

  String? selectedGrade;
  final section = TextEditingController();
  TeacherStaffRole roleType = TeacherStaffRole.subjectTeacher;
  List<String> selectedSubjects = [];
  List<SubjectTeachingSlot> existingSlots = const [];

  void dispose() {
    section.dispose();
  }
}

/// Resolves class assignments from a teacher record, including legacy strings.
List<TeacherClassAssignment> teacherClassAssignmentsFromRecord(
  AdminTeacherRecord teacher,
) {
  if (teacher.classAssignments.isNotEmpty) {
    return List<TeacherClassAssignment>.from(teacher.classAssignments);
  }
  return _legacyAssignmentsFromString(teacher);
}

List<TeacherClassAssignmentEntry> teacherAssignmentEntriesFromRecord(
  AdminTeacherRecord teacher, {
  List<String> schoolGrades = const [],
}) {
  final assignments = teacherClassAssignmentsFromRecord(teacher);

  if (assignments.isEmpty) {
    return [TeacherClassAssignmentEntry()];
  }

  return assignments.map((assignment) {
    final entry = TeacherClassAssignmentEntry();
    final parts = StudentRegistryService.parseClassNameParts(assignment.className);
    if (parts != null && parts.section.isNotEmpty) {
      entry.selectedGrade = _normalizeGradeForPicker(parts.grade, schoolGrades);
      entry.section.text = parts.section;
    } else {
      entry.selectedGrade =
          _normalizeGradeForPicker(assignment.className, schoolGrades);
      entry.section.text = parts?.section ?? '';
    }
    entry.roleType = assignment.role;
    entry.selectedSubjects = List<String>.from(assignment.subjectNames);
    entry.existingSlots = List<SubjectTeachingSlot>.from(assignment.teachingSlots);
    return entry;
  }).toList();
}

String? _normalizeGradeForPicker(String grade, List<String> schoolGrades) {
  final trimmed = grade.trim();
  if (trimmed.isEmpty) return null;
  if (schoolGrades.isEmpty) return trimmed;
  for (final option in schoolGrades) {
    if (option.toLowerCase() == trimmed.toLowerCase()) return option;
  }
  for (final option in schoolGrades) {
    if (trimmed.toLowerCase().startsWith(option.toLowerCase())) return option;
  }
  return trimmed;
}

/// Uses edited rows when complete; otherwise keeps [fallback] for edit flows.
List<TeacherClassAssignment> resolveTeacherClassAssignmentsForSave({
  required List<TeacherClassAssignmentEntry> entries,
  required List<TeacherClassAssignment> fallback,
}) {
  final built = buildTeacherClassAssignments(entries);
  if (built.isNotEmpty) return built;
  return List<TeacherClassAssignment>.from(fallback);
}

List<TeacherClassAssignment> buildTeacherClassAssignments(
  List<TeacherClassAssignmentEntry> entries,
) {
  final assignments = <TeacherClassAssignment>[];
  for (final entry in entries) {
    final grade = entry.selectedGrade?.trim() ?? '';
    final section = entry.section.text.trim();
    if (grade.isEmpty || section.isEmpty) continue;
    assignments.add(
      TeacherClassAssignment(
        className: StudentRegistryService.buildClassName(grade, section),
        role: entry.roleType,
        // Subjects are independent of HR/ST authority — keep for both roles.
        teachingSlots: TeacherRegistryService.instance.buildTeachingSlots(
          entry.selectedSubjects,
          existing: entry.existingSlots,
        ),
      ),
    );
  }
  return assignments;
}

Future<void> ensureTeacherAssignmentSections(
  List<TeacherClassAssignmentEntry> entries,
) async {
  for (final entry in entries) {
    final grade = entry.selectedGrade?.trim();
    final section = entry.section.text.trim();
    if (grade == null || grade.isEmpty || section.isEmpty) continue;
    await ClassStructureService.instance.ensureSectionForGrade(grade, section);
  }
}

void disposeTeacherAssignmentEntries(List<TeacherClassAssignmentEntry> entries) {
  for (final entry in entries) {
    entry.dispose();
  }
}

List<TeacherClassAssignment> _legacyAssignmentsFromString(
  AdminTeacherRecord teacher,
) {
  final classes = teacher.assignedClass
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (classes.isEmpty) return const [];

  final hasHomeroom = teacher.roles.contains(TeacherStaffRole.homeroomTeacher);
  final hasSubject = teacher.roles.contains(TeacherStaffRole.subjectTeacher);
  final assignments = <TeacherClassAssignment>[];

  for (var i = 0; i < classes.length; i++) {
    if (i == 0 && hasHomeroom) {
      assignments.add(
        TeacherClassAssignment(
          className: classes[i],
          role: TeacherStaffRole.homeroomTeacher,
        ),
      );
    } else if (hasSubject || (i > 0 && hasHomeroom)) {
      assignments.add(
        TeacherClassAssignment(
          className: classes[i],
          role: TeacherStaffRole.subjectTeacher,
        ),
      );
    }
  }
  return assignments;
}

/// Reusable grade/section/role editor for add + edit teacher flows.
class TeacherClassAssignmentEditor extends StatelessWidget {
  const TeacherClassAssignmentEditor({
    super.key,
    required this.entries,
    required this.onChanged,
    required this.accent,
    required this.secondary,
    required this.schoolGrades,
  });

  final List<TeacherClassAssignmentEntry> entries;
  final VoidCallback onChanged;
  final Color accent;
  final Color secondary;
  final List<String> schoolGrades;

  void _addEntry() {
    entries.add(TeacherClassAssignmentEntry());
    onChanged();
  }

  void _removeEntry(int index) {
    if (entries.length <= 1) return;
    entries[index].dispose();
    entries.removeAt(index);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          final existingSections = entry.selectedGrade == null
              ? <String>[]
              : ClassStructureService.instance
                  .sectionsForGrade(entry.selectedGrade!);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.12),
                  secondary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    adminStatusChip(
                      label: s.classNumberLabel(index + 1),
                      color: accent,
                      icon: Icons.class_,
                    ),
                    const Spacer(),
                    if (entries.length > 1)
                      IconButton(
                        onPressed: () => _removeEntry(index),
                        icon: Icon(Icons.close, color: Colors.red.shade400),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('grade-$index-${entry.selectedGrade}'),
                  initialValue: entry.selectedGrade != null &&
                          schoolGrades.contains(entry.selectedGrade)
                      ? entry.selectedGrade
                      : null,
                  decoration: adminFieldDecoration(
                    label: s.grade,
                    icon: Icons.stairs_outlined,
                    accent: secondary,
                  ),
                  hint: Text(s.selectGrade),
                  items: schoolGrades
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g),
                        ),
                      )
                      .toList(),
                  onChanged: schoolGrades.isEmpty
                      ? null
                      : (value) {
                          entry.selectedGrade = value;
                          onChanged();
                        },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: entry.section,
                  textCapitalization: TextCapitalization.characters,
                  decoration: adminFieldDecoration(
                    label: s.section,
                    hint: s.sectionAutoCreateHint,
                    icon: Icons.grid_view_outlined,
                    accent: secondary,
                  ),
                  onChanged: (_) => onChanged(),
                ),
                if (entry.selectedGrade != null &&
                    entry.section.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.classAssignmentPreview(
                      StudentRegistryService.buildClassName(
                        entry.selectedGrade!,
                        entry.section.text,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.9),
                    ),
                  ),
                ],
                if (existingSections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: existingSections
                        .map(
                          (sec) => ActionChip(
                            label: Text(sec),
                            onPressed: () {
                              entry.section.text = sec;
                              onChanged();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<TeacherStaffRole>(
                  key: ValueKey('role-$index-${entry.roleType.name}'),
                  initialValue: entry.roleType,
                  decoration: adminFieldDecoration(
                    label: s.classRole,
                    icon: Icons.work_outline,
                    accent: secondary,
                  ),
                  items: const [
                    TeacherStaffRole.homeroomTeacher,
                    TeacherStaffRole.subjectTeacher,
                  ]
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(s.teacherRoleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      entry.roleType = value;
                      onChanged();
                    }
                  },
                ),
                const SizedBox(height: 8),
                SubjectMultiPicker(
                  selected: entry.selectedSubjects,
                  onChanged: (values) {
                    entry.selectedSubjects = values;
                    onChanged();
                  },
                  accent: accent,
                  label: s.subject,
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addEntry,
          icon: Icon(Icons.add_circle_outline, color: accent),
          label: Text(s.addClassAssignment),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
