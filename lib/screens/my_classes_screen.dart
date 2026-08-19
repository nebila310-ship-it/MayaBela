import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/daily_activities_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/widgets/invite_parent_actions.dart';
import 'package:mayabela/widgets/student_avatar.dart';
import 'package:mayabela/widgets/class_picker_bar.dart';
import 'package:mayabela/widgets/class_tools_panel.dart';
import 'package:mayabela/widgets/teaching_slot_qr.dart';
import 'package:mayabela/theme/teacher_theme.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
const _classAccent = TeacherTheme.primaryDark;
const _classAccentLight = TeacherTheme.primary;

class MyClassesScreen extends StatelessWidget {
  const MyClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final classes = TeacherAccessService.instance.myClasses;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: _classAccent,
            foregroundColor: Colors.white,
            title: Text(s.myClasses),
          ),
          body: WarmScreenBody(
            accentColor: _classAccent,
            child: classes.isEmpty
                ? Center(child: Text(s.noClassesAssigned))
                : ListView.separated(
                    padding: listPagePadding(context),
                    itemCount: classes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final assignment = classes[index];
                      final slots = TeacherAccessService.instance
                          .teachingSlotsFor(assignment.className);
                      return Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        elevation: 1,
                        shadowColor: _classAccent.withValues(alpha: 0.1),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClassDetailScreen(
                                  assignment: assignment,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: assignment.isHomeroom
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : _classAccent.withValues(alpha: 0.12),
                                  child: Icon(
                                    assignment.isHomeroom
                                        ? Icons.home_work
                                        : Icons.menu_book,
                                    color: assignment.isHomeroom
                                        ? Colors.green.shade700
                                        : _classAccent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        assignment.className,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        assignment.isHomeroom
                                            ? s.homeroomTeacher
                                            : assignment.subject ??
                                                s.subjectTeacher,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '${s.studentsCount(assignment.studentCount)} · ${assignment.schedule}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (slots.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: slots
                                              .take(3)
                                              .map(
                                                (slot) => Chip(
                                                  label: Text(
                                                    '${slot.subjectName} · ${slot.slotId}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  backgroundColor: _classAccent
                                                      .withValues(alpha: 0.08),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: assignment.isHomeroom
                                        ? Colors.green.shade50
                                        : _classAccent.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: assignment.isHomeroom
                                          ? Colors.green.shade200
                                          : _classAccentLight.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    assignment.isHomeroom
                                        ? s.fullAccess
                                        : s.subjectTeacherAccessChip,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: assignment.isHomeroom
                                          ? Colors.green.shade800
                                          : _classAccent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, color: _classAccentLight),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.assignment});

  final ClassAssignment assignment;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  List<StudentRef> get _students => SchoolDataService.instance
      .getStudentsForClass(widget.assignment.className);

  List<SubjectTeachingSlot> get _teachingSlots =>
      TeacherAccessService.instance
          .teachingSlotsFor(widget.assignment.className);

  void _refreshPhotos() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final access = TeacherAccessService.instance;
    final assignment = widget.assignment;
    final isHomeroom = assignment.isHomeroom;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          appBar: AppBar(
            backgroundColor: _classAccent,
            foregroundColor: Colors.white,
            title: Text(assignment.className),
            actions: [
              if (isHomeroom)
                IconButton(
                  icon: const Icon(Icons.sms_outlined),
                  tooltip: s.inviteBulkTitle,
                  onPressed: () => showBulkParentInviteDialog(
                    context,
                    students: studentsForActiveSchoolClass(assignment.className),
                    classLabel: assignment.className,
                  ),
                ),
            ],
          ),
          body: WarmScreenBody(
            accentColor: _classAccent,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _classAccentLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isHomeroom
                                      ? s.homeroomClass
                                      : assignment.subject ?? '',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _classAccent,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isHomeroom
                                      ? Colors.green.shade50
                                      : _classAccent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isHomeroom
                                      ? s.fullAccess
                                      : s.subjectTeacherAccessChip,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isHomeroom
                                        ? Colors.green.shade800
                                        : _classAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (assignment.homeroomTeacherName != null)
                            _infoRow(
                              Icons.person,
                              '${s.homeroomTeacher}: ${assignment.homeroomTeacherName}',
                            ),
                          _infoRow(Icons.schedule, assignment.schedule),
                          _infoRow(Icons.meeting_room, assignment.room),
                          _infoRow(
                            Icons.people,
                            s.studentsCount(_students.length),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ClassToolsPanel.fromAssignment(
                      assignment,
                      accent: _classAccent,
                    ),
                  ),
                ),
                if (_teachingSlots.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _TeachingSlotsPanel(
                        className: assignment.className,
                        slots: _teachingSlots,
                        accent: _classAccent,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      s.studentsTapPhoto,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _classAccent,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: listPagePadding(context),
                  sliver: SliverList.separated(
                    itemCount: _students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return Material(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _classAccent.withValues(alpha: 0.08),
                            ),
                          ),
                          leading: StudentAvatar(
                            student: student,
                            allowEdit: false,
                            onPhotoUpdated: _refreshPhotos,
                          ),
                          title: Text(student.name),
                          subtitle: Text(
                            student.parentName != null
                                ? s.parentOf(student.parentName!)
                                : student.grade,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isHomeroom)
                                InviteParentButton(
                                  studentRef: student,
                                  compact: true,
                                ),
                              if (access.canMessageInClass(assignment.className))
                                IconButton(
                                  icon: Icon(
                                    Icons.message,
                                    color: Colors.orange.shade700,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MessagesScreen(),
                                      ),
                                    );
                                  },
                                ),
                              if (isHomeroom)
                                IconButton(
                                  icon: Icon(
                                    Icons.today,
                                    color: Colors.teal.shade700,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudentDetailScreen(
                                          student: student,
                                          className: assignment.className,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          onTap: isHomeroom
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentDetailScreen(
                                        student: student,
                                        className: assignment.className,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _classAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TeachingSlotsPanel extends StatelessWidget {
  const _TeachingSlotsPanel({
    required this.className,
    required this.slots,
    required this.accent,
  });

  final String className;
  final List<SubjectTeachingSlot> slots;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final access = TeacherAccessService.instance;
    final schoolId =
        AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.teachingAssignmentsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          ...slots.map(
            (slot) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: accent.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showTeachingSlotQrSheet(
                    context,
                    slot: slot,
                    className: className,
                    teacherId: access.teacherId,
                    teacherName: access.teacherName,
                    schoolId: schoolId,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: accent.withValues(alpha: 0.12),
                          child: Icon(Icons.menu_book, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.subjectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${s.subjectIdLabel}: ${slot.subjectId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                '${s.teachingSlotIdLabel}: ${slot.slotId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.qr_code_2, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({
    super.key,
    required this.student,
    required this.className,
  });

  final StudentRef student;
  final String className;

  @override
  Widget build(BuildContext context) {
    final liveStudent =
        SchoolDataService.instance.getStudentRef(student.id) ?? student;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(liveStudent.name),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      StudentAvatar(
                        student: liveStudent,
                        radius: 36,
                        allowEdit: false,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              liveStudent.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$className · ${s.gradeLevel(liveStudent.grade)}',
                            ),
                            if (liveStudent.parentName != null)
                              Text(s.parentOf(liveStudent.parentName!)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DailyActivitiesScreen(
                        studentId: liveStudent.inviteStudentId,
                        studentName: liveStudent.name,
                        className: className,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.today),
                label: Text(s.dailyActivities),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                },
                icon: const Icon(Icons.message),
                label: Text(
                  s.messageTo(liveStudent.parentName ?? s.parentLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
