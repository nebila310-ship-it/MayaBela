import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/section_teacher_assignment_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/subject_multi_picker.dart';

/// Pick a registered teacher for this section (homeroom or subject).
Future<void> showAssignHomeroomTeacherDialog({
  required BuildContext context,
  required String className,
  String? currentTeacherId,
}) async {
  final s = AppLocale.instance.strings;
  final schoolId = AuthService.activeSchoolId;
  final teachers = TeacherRegistryService.instance
      .staffTeachersForSchool(schoolId)
      .where((t) => t.isActive)
      .toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));

  String? selected = currentTeacherId?.trim().toUpperCase();
  if (selected != null &&
      selected.isNotEmpty &&
      !teachers.any((t) => t.teacherId == selected)) {
    selected = null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(s.homeroomTeacher),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    className,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (teachers.isEmpty)
                    Text(s.noTeachersInSection)
                  else
                    DropdownButtonFormField<String?>(
                      initialValue: selected,
                      decoration: InputDecoration(
                        labelText: s.teachersTab,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('— None —'),
                        ),
                        ...teachers.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t.teacherId,
                            child: Text('${t.fullName} (${t.teacherId})'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => selected = v),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: teachers.isEmpty && selected == null
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(s.save),
              ),
            ],
          );
        },
      );
    },
  );

  if (ok != true || !context.mounted) return;
  await SectionTeacherAssignmentService.instance.setHomeroomTeacher(
    className: className,
    teacherId: selected,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.teacherUpdated),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}

Future<void> showAssignSubjectTeacherDialog({
  required BuildContext context,
  required String className,
  String? teacherId,
  List<String> initialSubjects = const [],
}) async {
  final s = AppLocale.instance.strings;
  final schoolId = AuthService.activeSchoolId;
  final teachers = TeacherRegistryService.instance
      .staffTeachersForSchool(schoolId)
      .where((t) => t.isActive)
      .toList()
    ..sort((a, b) => a.fullName.compareTo(b.fullName));

  String? selected = teacherId?.trim().toUpperCase();
  if (selected != null &&
      selected.isNotEmpty &&
      !teachers.any((t) => t.teacherId == selected)) {
    selected = null;
  }
  var subjects = List<String>.from(initialSubjects);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(s.subjectTeacher),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      className,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (teachers.isEmpty)
                      Text(s.noTeachersInSection)
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          labelText: s.teachersTab,
                          border: const OutlineInputBorder(),
                        ),
                        items: teachers
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.teacherId,
                                child: Text('${t.fullName} (${t.teacherId})'),
                              ),
                            )
                            .toList(),
                        onChanged: teacherId != null
                            ? null
                            : (v) => setLocal(() => selected = v),
                      ),
                    const SizedBox(height: 12),
                    SubjectMultiPicker(
                      selected: subjects,
                      onChanged: (values) => setLocal(() => subjects = values),
                      accent: Colors.indigo,
                      label: s.subject,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: selected == null || subjects.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: Text(s.save),
              ),
            ],
          );
        },
      );
    },
  );

  if (ok != true || selected == null || !context.mounted) return;
  await SectionTeacherAssignmentService.instance.upsertSubjectTeacher(
    className: className,
    teacherId: selected!,
    subjects: subjects,
  );
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.teacherUpdated),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }
}
