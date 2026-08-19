import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/text_input_formatters.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/phone_contact_field.dart';
import 'package:mayabela/widgets/transport_driver_field.dart';

/// Opens a full student edit dialog matching the add-student enrollment form.
Future<bool?> showAdminStudentEditDialog(
  BuildContext context, {
  required AdminStudentRecord student,
}) async {
  final s = AppLocale.instance.strings;
  final theme = AdminFormTheme.student;

  final nameCtrl = TextEditingController(text: student.fullName);
  final fatherCtrl = TextEditingController(text: student.fatherName ?? '');
  final fatherPhoneCtrl = TextEditingController(text: student.fatherPhone ?? '');
  final motherCtrl = TextEditingController(text: student.motherName ?? '');
  final motherPhoneCtrl = TextEditingController(text: student.motherPhone ?? '');
  final guardianCtrl = TextEditingController(text: student.guardianName ?? '');
  final guardianPhoneCtrl =
      TextEditingController(text: student.guardianPhone ?? '');
  final emergencyName1Ctrl =
      TextEditingController(text: student.emergencyContact1Name ?? '');
  final emergencyPhone1Ctrl =
      TextEditingController(text: student.emergencyPhone1 ?? '');
  final emergencyName2Ctrl =
      TextEditingController(text: student.emergencyContact2Name ?? '');
  final emergencyPhone2Ctrl =
      TextEditingController(text: student.emergencyPhone2 ?? '');
  final dobCtrl = TextEditingController(
    text: ParentInviteService.formatDob(student.dateOfBirth),
  );
  final academicYearCtrl =
      TextEditingController(text: student.academicYear ?? '2025/2026');
  final homeroomTeacherIdCtrl =
      TextEditingController(text: student.homeroomTeacherId ?? '');
  final transportIdCtrl = TextEditingController(text: student.transportId ?? '');

  final campusOptions = SchoolRegistryService.instance
      .campusesForSchool(student.schoolId)
      .toList();
  if (!campusOptions.contains(student.campus)) {
    campusOptions.insert(0, student.campus);
  }
  var selectedCampus = student.campus;

  final parts = StudentRegistryService.parseClassNameParts(student.className);
  String? selectedGrade = parts?.grade ?? student.grade;
  final sectionCtrl = TextEditingController(text: parts?.section ?? '');
  String? selectedGender = student.gender;
  var transportEnabled = student.transportEnabled;
  AdminTeacherRecord? homeroomTeacher;
  String? homeroomLookupMessage;
  var homeroomLookupOk = student.homeroomTeacherId?.trim().isNotEmpty == true;

  if (student.homeroomTeacherId != null &&
      student.homeroomTeacherId!.trim().isNotEmpty) {
    homeroomTeacher =
        TeacherRegistryService.instance.lookupById(student.homeroomTeacherId!);
    if (homeroomTeacher != null) {
      homeroomLookupMessage = homeroomTeacher.fullName;
      homeroomLookupOk = true;
    }
  }

  const genders = ['Male', 'Female'];
  final schoolGrades = ClassStructureService.instance.gradesForSchool();

  List<PhoneDialOption> allDialOptions({String? excludeController}) {
    final options = <PhoneDialOption>[];
    void add(String label, TextEditingController c) {
      if (c.text.trim().isEmpty) return;
      if (excludeController != null && c.text == excludeController) return;
      options.add(PhoneDialOption(label: label, phone: c.text.trim()));
    }

    add(s.fatherPhone, fatherPhoneCtrl);
    add(s.motherPhone, motherPhoneCtrl);
    add(s.guardianPhoneOptional, guardianPhoneCtrl);
    add(s.emergencyPhone, emergencyPhone1Ctrl);
    add(s.emergencyPhone, emergencyPhone2Ctrl);
    return options;
  }

  List<PhoneDialOption> fallbackFor(TextEditingController self, String label) {
    return allDialOptions()
        .where((o) => o.phone != self.text.trim())
        .toList();
  }

  DateTime? parseDob(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    try {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  void lookupHomeroomTeacher(StateSetter setDialogState) {
    final id = homeroomTeacherIdCtrl.text.trim();
    if (id.isEmpty) {
      setDialogState(() {
        homeroomTeacher = null;
        homeroomLookupMessage = null;
        homeroomLookupOk = false;
      });
      return;
    }

    final teacher = TeacherRegistryService.instance.lookupById(id);
    if (teacher == null ||
        teacher.schoolId.toUpperCase() != student.schoolId.toUpperCase()) {
      setDialogState(() {
        homeroomTeacher = null;
        homeroomLookupMessage = s.teacherNotFoundForSchool;
        homeroomLookupOk = false;
      });
      return;
    }

    setDialogState(() {
      homeroomTeacher = teacher;
      homeroomLookupMessage = teacher.fullName;
      homeroomLookupOk = true;
    });
  }

  void refreshHomeroomForClass(StateSetter setDialogState) {
    if (selectedGrade == null || sectionCtrl.text.trim().isEmpty) {
      setDialogState(() {
        homeroomTeacher = null;
        homeroomTeacherIdCtrl.clear();
        homeroomLookupMessage = null;
        homeroomLookupOk = false;
      });
      return;
    }

    final grade = selectedGrade!;
    final section = sectionCtrl.text.trim();
    final className =
        ClassStructureService.instance.classNameFor(grade, section);
    final teachers =
        ClassStructureService.instance.teachersForSection(grade, section);
    ClassTeacherInfo? homeroom;
    for (final entry in teachers) {
      if (entry.isHomeroom) {
        homeroom = entry;
        break;
      }
    }

    if (homeroom != null) {
      final resolved = homeroom;
      setDialogState(() {
        homeroomTeacher = resolved.teacher;
        homeroomTeacherIdCtrl.text = resolved.teacher.teacherId;
        homeroomLookupMessage = resolved.teacher.fullName;
        homeroomLookupOk = true;
      });
      return;
    }

    final fallbackId =
        SchoolDataService.instance.homeroomTeacherIdForClass(className);
    if (fallbackId != null) {
      final teacher = TeacherRegistryService.instance.lookupById(fallbackId);
      if (teacher != null) {
        setDialogState(() {
          homeroomTeacher = teacher;
          homeroomTeacherIdCtrl.text = teacher.teacherId;
          homeroomLookupMessage = teacher.fullName;
          homeroomLookupOk = true;
        });
        return;
      }
    }

    setDialogState(() {
      homeroomTeacher = null;
      homeroomTeacherIdCtrl.clear();
      homeroomLookupMessage = s.noHomeroomTeacherForClass;
      homeroomLookupOk = false;
    });
  }

  final saved = await showAdminFormDialog(
    context: context,
    title: s.editStudent,
    subtitle: student.fullName,
    accent: theme.primary,
    icon: Icons.person_outline,
    builder: (ctx, setDialogState) {
      final existingSections = selectedGrade == null
          ? <String>[]
          : ClassStructureService.instance.sectionsForGrade(selectedGrade!);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFormDialogSection(
            title: s.fullName,
            icon: Icons.badge_outlined,
            color: theme.primary,
            children: [
              adminDialogField(
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.person_outline,
                    accent: theme.primary,
                  ),
                ),
              ),
              adminDialogField(
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedGender),
                  initialValue: selectedGender,
                  decoration: adminFieldDecoration(
                    label: s.gender,
                    icon: Icons.wc_outlined,
                    accent: theme.primary,
                  ),
                  items: genders
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(
                            g == 'Male' ? s.genderMale : s.genderFemale,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedGender = v),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.fatherDetails,
            icon: Icons.man_outlined,
            color: const Color(0xFF1565C0),
            children: [
              adminDialogField(
                TextField(
                  controller: fatherCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fatherName,
                    icon: Icons.person,
                    accent: const Color(0xFF1565C0),
                  ),
                ),
              ),
              adminDialogField(
                PhoneContactField(
                  controller: fatherPhoneCtrl,
                  label: s.fatherPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers:
                      fallbackFor(fatherPhoneCtrl, s.fatherPhone),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.motherDetails,
            icon: Icons.woman_outlined,
            color: const Color(0xFFAD1457),
            children: [
              adminDialogField(
                TextField(
                  controller: motherCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.motherName,
                    icon: Icons.person,
                    accent: const Color(0xFFAD1457),
                  ),
                ),
              ),
              adminDialogField(
                PhoneContactField(
                  controller: motherPhoneCtrl,
                  label: s.motherPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers:
                      fallbackFor(motherPhoneCtrl, s.motherPhone),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.guardianDetailsOptional,
            icon: Icons.family_restroom_outlined,
            color: const Color(0xFF6A1B9A),
            children: [
              adminDialogField(
                TextField(
                  controller: guardianCtrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.guardianNameOptional,
                    icon: Icons.person_outline,
                    accent: const Color(0xFF6A1B9A),
                  ),
                ),
              ),
              adminDialogField(
                PhoneContactField(
                  controller: guardianPhoneCtrl,
                  label: s.guardianPhoneOptional,
                  hint: s.phoneLoginHint,
                  fallbackNumbers: fallbackFor(
                    guardianPhoneCtrl,
                    s.guardianPhoneOptional,
                  ),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.emergencyContactsSection,
            icon: Icons.contact_emergency_outlined,
            color: const Color(0xFFE65100),
            children: [
              adminDialogField(
                TextField(
                  controller: emergencyName1Ctrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.emergencyContactName,
                    accent: const Color(0xFFE65100),
                  ),
                ),
              ),
              adminDialogField(
                PhoneContactField(
                  controller: emergencyPhone1Ctrl,
                  label: s.emergencyPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers:
                      fallbackFor(emergencyPhone1Ctrl, s.emergencyPhone),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: emergencyName2Ctrl,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.emergencyContactName,
                    accent: const Color(0xFFE65100),
                  ),
                ),
              ),
              adminDialogField(
                PhoneContactField(
                  controller: emergencyPhone2Ctrl,
                  label: s.emergencyPhone,
                  hint: s.phoneLoginHint,
                  fallbackNumbers:
                      fallbackFor(emergencyPhone2Ctrl, s.emergencyPhone),
                ),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.schoolEnrollmentDetails,
            icon: Icons.school_outlined,
            color: theme.secondary,
            children: [
              adminDialogField(
                DropdownButtonFormField<String>(
                  initialValue: selectedCampus,
                  decoration: adminFieldDecoration(
                    label: s.campus,
                    icon: Icons.location_city_outlined,
                    accent: theme.secondary,
                  ),
                  items: campusOptions
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedCampus = value;
                  },
                ),
              ),
              adminDialogField(
                TextField(
                  controller: academicYearCtrl,
                  decoration: adminFieldDecoration(
                    label: s.academicYear,
                    hint: '2025/2026',
                    icon: Icons.calendar_today_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
              adminDialogField(
                TextField(
                  controller: dobCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: dateSlashFormatters,
                  decoration: adminFieldDecoration(
                    label: s.studentDateOfBirth,
                    hint: s.dateFormatHint,
                    icon: Icons.cake_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
              adminDialogField(
                DropdownButtonFormField<String>(
                  key: ValueKey(selectedGrade),
                  initialValue: selectedGrade != null &&
                          schoolGrades.contains(selectedGrade)
                      ? selectedGrade
                      : null,
                  decoration: adminFieldDecoration(
                    label: s.grade,
                    icon: Icons.stairs_outlined,
                    accent: theme.secondary,
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
                      : (v) {
                          setDialogState(() => selectedGrade = v);
                          refreshHomeroomForClass(setDialogState);
                        },
                ),
              ),
              adminDialogField(
                TextField(
                  controller: sectionCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => refreshHomeroomForClass(setDialogState),
                  decoration: adminFieldDecoration(
                    label: s.section,
                    hint: s.sectionAutoCreateHint,
                    icon: Icons.grid_view_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
              if (existingSections.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: existingSections
                      .map(
                        (sec) => ActionChip(
                          label: Text(sec),
                          onPressed: () {
                            setDialogState(() => sectionCtrl.text = sec);
                            refreshHomeroomForClass(setDialogState);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              adminDialogField(
                TextField(
                  controller: homeroomTeacherIdCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => lookupHomeroomTeacher(setDialogState),
                  decoration: adminFieldDecoration(
                    label: s.homeroomTeacherId,
                    hint: 'TCH-1001',
                    icon: Icons.person_search_outlined,
                    accent: theme.secondary,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => lookupHomeroomTeacher(setDialogState),
                  icon: const Icon(Icons.search),
                  label: Text(s.lookupTeacher),
                ),
              ),
              if (homeroomLookupMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: homeroomLookupOk
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: homeroomLookupOk
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        homeroomLookupOk ? Icons.check_circle : Icons.error_outline,
                        color: homeroomLookupOk ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(homeroomLookupMessage!)),
                    ],
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.transportEnabled),
                subtitle: Text(
                  s.schoolTransportIdOptionalHint,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: transportEnabled,
                activeTrackColor: theme.primary.withValues(alpha: 0.45),
                activeThumbColor: theme.primary,
                onChanged: (v) => setDialogState(() {
                  transportEnabled = v;
                  if (!v) transportIdCtrl.clear();
                }),
              ),
              if (transportEnabled)
                adminDialogField(
                  TransportDriverField(
                    controller: transportIdCtrl,
                    schoolId: student.schoolId,
                    accent: theme.primary,
                    onChanged: () => setDialogState(() {}),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );

  if (saved != true) return false;
  if (!context.mounted) return false;

  if (selectedGrade == null || sectionCtrl.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.gradeSectionRequired)),
    );
    return false;
  }

  if (selectedGender == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.selectGender)),
    );
    return false;
  }

  final dob = parseDob(dobCtrl.text);
  if (dob == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.invalidDateFormat)),
    );
    return false;
  }

  if (homeroomTeacherIdCtrl.text.trim().isNotEmpty && !homeroomLookupOk) {
    return false;
  }

  final grade = selectedGrade!.trim();
  await ClassStructureService.instance.ensureSectionForGrade(
    grade,
    sectionCtrl.text.trim(),
  );
  if (!context.mounted) return false;

  final className = StudentRegistryService.buildClassName(
    grade,
    sectionCtrl.text,
  );

  var homeroomTeacherId = homeroomTeacher?.teacherId;
  if (homeroomTeacherId == null || homeroomTeacherId.isEmpty) {
    final typed = homeroomTeacherIdCtrl.text.trim();
    homeroomTeacherId = typed.isEmpty ? null : typed;
  }
  homeroomTeacherId ??=
      SchoolDataService.instance.homeroomTeacherIdForClass(className);

  final transportIdRaw =
      transportEnabled ? transportIdCtrl.text.trim() : '';
  if (transportEnabled && transportIdRaw.isNotEmpty) {
    final transportError = ParentInviteService.instance.validateTransportId(
      transportIdRaw,
      schoolId: student.schoolId,
    );
    if (transportError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transportError == 'wrong_school'
                ? s.transportIdWrongSchool
                : s.transportBusNotRegisteredWithId(
                    transportIdRaw.toUpperCase(),
                  ),
          ),
        ),
      );
      return false;
    }
  }

  StudentRegistryService.instance.updateStudent(
    student.copyWith(
      fullName: nameCtrl.text.trim(),
      gender: selectedGender,
      fatherName: fatherCtrl.text.trim().isEmpty ? null : fatherCtrl.text.trim(),
      motherName: motherCtrl.text.trim().isEmpty ? null : motherCtrl.text.trim(),
      fatherPhone:
          fatherPhoneCtrl.text.trim().isEmpty ? null : fatherPhoneCtrl.text.trim(),
      motherPhone:
          motherPhoneCtrl.text.trim().isEmpty ? null : motherPhoneCtrl.text.trim(),
      guardianName:
          guardianCtrl.text.trim().isEmpty ? null : guardianCtrl.text.trim(),
      guardianPhone: guardianPhoneCtrl.text.trim().isEmpty
          ? null
          : guardianPhoneCtrl.text.trim(),
      emergencyContact1Name: emergencyName1Ctrl.text.trim().isEmpty
          ? null
          : emergencyName1Ctrl.text.trim(),
      emergencyPhone1: emergencyPhone1Ctrl.text.trim().isEmpty
          ? null
          : emergencyPhone1Ctrl.text.trim(),
      emergencyContact2Name: emergencyName2Ctrl.text.trim().isEmpty
          ? null
          : emergencyName2Ctrl.text.trim(),
      emergencyPhone2: emergencyPhone2Ctrl.text.trim().isEmpty
          ? null
          : emergencyPhone2Ctrl.text.trim(),
      dateOfBirth: dob,
      grade: grade,
      className: className,
      campus: selectedCampus,
      academicYear: academicYearCtrl.text.trim(),
      homeroomTeacherId: homeroomTeacherId,
      transportEnabled: transportEnabled,
      transportId: transportEnabled && transportIdRaw.isNotEmpty
          ? transportIdRaw
          : null,
      clearTransportId: !transportEnabled || transportIdRaw.isEmpty,
    ),
  );
  SchoolDataService.instance.syncChildFromRegistry(student.studentId);
  return true;
}
