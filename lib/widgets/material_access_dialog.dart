import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Admin/teacher dialog to unlock a paid learning material per student.
Future<void> showMaterialAccessDialog({
  required BuildContext context,
  required LearningMaterialItem material,
  Color accent = const Color(0xFF4527A0),
}) async {
  final access = MaterialAccessService.instance;
  await access.ensureLoaded();
  if (!context.mounted) return;

  final students = StudentRegistryService.instance.studentsForClass(
    material.className,
    schoolId: AuthService.activeSchoolId,
  )..sort((a, b) => a.fullName.compareTo(b.fullName));

  final grantedBy = AuthService.currentUser?.username ?? 'admin';
  var changed = false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      final s = AppLocale.instance.strings;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final unlocked = access.unlockedStudentIds(material.id);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_open_outlined, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.studentAccessTitle,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: students.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(s.noStudentsForClass),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${material.bookName} · ${material.className}\n'
                          '${unlocked.length}/${students.length} ${s.unlockedForCount}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final sid = student.studentId.toUpperCase();
                                final has = unlocked.contains(sid);
                                return CheckboxListTile(
                                  dense: true,
                                  activeColor: accent,
                                  value: has,
                                  title: Text(student.fullName),
                                  subtitle: Text(student.studentId),
                                  onChanged: (value) {
                                    changed = true;
                                    if (value == true) {
                                      access.grant(
                                        materialId: material.id,
                                        studentId: sid,
                                        grantedBy: grantedBy,
                                      );
                                    } else {
                                      access.revoke(
                                        materialId: material.id,
                                        studentId: sid,
                                      );
                                    }
                                    setDialogState(() {});
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () => Navigator.pop(context),
                child: Text(s.done),
              ),
            ],
          );
        },
      );
    },
  );

  if (changed && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocale.instance.strings.materialAccessUpdated),
        backgroundColor: Colors.green,
      ),
    );
  }
}
