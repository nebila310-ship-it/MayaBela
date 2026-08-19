import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/transfer_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

enum StudentTransferKind { section, grade, transport, campus }

enum TeacherTransferKind { section, grade, campus }

/// Opens the transfer hub, optionally on a specific tab.
class AdminTransferScreen extends StatelessWidget {
  const AdminTransferScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId ?? 'TB-001';
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final students =
            StudentRegistryService.instance.studentsForSchool(schoolId);
        final teachers =
            TeacherRegistryService.instance.staffTeachersForSchool(schoolId);
        final drivers =
            DriverRegistryService.instance.driversForSchool(schoolId);

        return DefaultTabController(
          length: 3,
          initialIndex: initialTab.clamp(0, 2),
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF3949AB),
              title: Text(s.transferHubTitle),
              bottom: TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: s.transferStudentsTab,
                    icon: const Icon(Icons.school_outlined),
                  ),
                  Tab(
                    text: s.transferTeachersTab,
                    icon: const Icon(Icons.person_outline),
                  ),
                  Tab(
                    text: s.transferDriversTab,
                    icon: const Icon(Icons.directions_bus_outlined),
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _TransferPeopleTab<AdminStudentRecord>(
                  accent: AdminFormTheme.student.primary,
                  rosterTitle: s.transferStudentsRoster(students.length),
                  emptyRoster: s.transferNoStudents,
                  people: students,
                  personLabel: (st) => '${st.fullName} · ${st.className}',
                  onTransferPerson: (st) =>
                      showStudentTransferKindPicker(context, studentId: st.studentId),
                  options: [
                    _TransferOption(
                      title: s.transferSectionToSection,
                      subtitle: s.transferSectionToSectionHint,
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => _openStudentTransfer(context, StudentTransferKind.section),
                    ),
                    _TransferOption(
                      title: s.transferGradeToGrade,
                      subtitle: s.transferGradeToGradeHint,
                      icon: Icons.stairs_outlined,
                      onTap: () => _openStudentTransfer(context, StudentTransferKind.grade),
                    ),
                    _TransferOption(
                      title: s.transferTransportToTransport,
                      subtitle: s.transferTransportToTransportHint,
                      icon: Icons.directions_bus_filled_outlined,
                      onTap: () => _openStudentTransfer(context, StudentTransferKind.transport),
                    ),
                    _TransferOption(
                      title: s.transferCampusToCampus,
                      subtitle: s.transferCampusToCampusHint,
                      icon: Icons.location_city_outlined,
                      onTap: () => _openStudentTransfer(context, StudentTransferKind.campus),
                    ),
                  ],
                ),
                _TransferPeopleTab<AdminTeacherRecord>(
                  accent: AdminFormTheme.teacher.primary,
                  rosterTitle: s.transferTeachersRoster(teachers.length),
                  emptyRoster: s.transferNoTeachers,
                  people: teachers,
                  personLabel: (t) => '${t.fullName} · ${t.assignedClass}',
                  onTransferPerson: (t) =>
                      showTeacherTransferKindPicker(context, teacherId: t.teacherId),
                  options: [
                    _TransferOption(
                      title: s.transferSectionToSection,
                      subtitle: s.transferTeacherSectionHint,
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => _openTeacherTransfer(context, TeacherTransferKind.section),
                    ),
                    _TransferOption(
                      title: s.transferGradeToGrade,
                      subtitle: s.transferTeacherGradeHint,
                      icon: Icons.stairs_outlined,
                      onTap: () => _openTeacherTransfer(context, TeacherTransferKind.grade),
                    ),
                    _TransferOption(
                      title: s.transferCampusToCampus,
                      subtitle: s.transferTeacherCampusHint,
                      icon: Icons.location_city_outlined,
                      onTap: () => _openTeacherTransfer(context, TeacherTransferKind.campus),
                    ),
                  ],
                ),
                _TransferPeopleTab<AdminDriverRecord>(
                  accent: AdminFormTheme.driver.primary,
                  rosterTitle: s.transferDriversRoster(drivers.length),
                  emptyRoster: s.transferNoDrivers,
                  people: drivers,
                  personLabel: (d) => '${d.fullName} · ${d.busNumber}',
                  onTransferPerson: (d) => openDriverBusTransfer(
                    context,
                    fromDriverId: d.driverId,
                  ),
                  options: [
                    _TransferOption(
                      title: s.transferBusToBus,
                      subtitle: s.transferBusToBusHint,
                      icon: Icons.compare_arrows_rounded,
                      onTap: () => openDriverBusTransfer(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openStudentTransfer(BuildContext context, StudentTransferKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTransferScreen(kind: kind),
      ),
    );
  }

  void _openTeacherTransfer(BuildContext context, TeacherTransferKind kind) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherTransferScreen(kind: kind),
      ),
    );
  }
}

void openDriverBusTransfer(
  BuildContext context, {
  String? fromDriverId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DriverBusTransferScreen(fromDriverId: fromDriverId),
    ),
  );
}

Future<void> showStudentTransferKindPicker(
  BuildContext context, {
  required String studentId,
}) {
  final s = AppLocale.instance.strings;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              s.transferChooseType,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          _kindTile(
            ctx,
            icon: Icons.swap_horiz_rounded,
            label: s.transferSectionToSection,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentTransferScreen(
                    kind: StudentTransferKind.section,
                    studentId: studentId,
                  ),
                ),
              );
            },
          ),
          _kindTile(
            ctx,
            icon: Icons.stairs_outlined,
            label: s.transferGradeToGrade,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentTransferScreen(
                    kind: StudentTransferKind.grade,
                    studentId: studentId,
                  ),
                ),
              );
            },
          ),
          _kindTile(
            ctx,
            icon: Icons.directions_bus_filled_outlined,
            label: s.transferTransportToTransport,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentTransferScreen(
                    kind: StudentTransferKind.transport,
                    studentId: studentId,
                  ),
                ),
              );
            },
          ),
          _kindTile(
            ctx,
            icon: Icons.location_city_outlined,
            label: s.transferCampusToCampus,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentTransferScreen(
                    kind: StudentTransferKind.campus,
                    studentId: studentId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> showTeacherTransferKindPicker(
  BuildContext context, {
  required String teacherId,
}) {
  if (!ModuleAccess.canAssignTeachers) return Future.value();
  final s = AppLocale.instance.strings;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              s.transferChooseType,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          _kindTile(
            ctx,
            icon: Icons.swap_horiz_rounded,
            label: s.transferSectionToSection,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherTransferScreen(
                    kind: TeacherTransferKind.section,
                    teacherId: teacherId,
                  ),
                ),
              );
            },
          ),
          _kindTile(
            ctx,
            icon: Icons.stairs_outlined,
            label: s.transferGradeToGrade,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherTransferScreen(
                    kind: TeacherTransferKind.grade,
                    teacherId: teacherId,
                  ),
                ),
              );
            },
          ),
          _kindTile(
            ctx,
            icon: Icons.location_city_outlined,
            label: s.transferCampusToCampus,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherTransferScreen(
                    kind: TeacherTransferKind.campus,
                    teacherId: teacherId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _kindTile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon, color: const Color(0xFF3949AB)),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _TransferOption {
  const _TransferOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _TransferPeopleTab<T> extends StatelessWidget {
  const _TransferPeopleTab({
    required this.accent,
    required this.options,
    required this.rosterTitle,
    required this.emptyRoster,
    required this.people,
    required this.personLabel,
    required this.onTransferPerson,
  });

  final Color accent;
  final List<_TransferOption> options;
  final String rosterTitle;
  final String emptyRoster;
  final List<T> people;
  final String Function(T) personLabel;
  final ValueChanged<T> onTransferPerson;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: listPagePadding(context),
      children: [
        Text(
          AppLocale.instance.strings.transferTypesHeading,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TransferOptionCard(accent: accent, option: options[i]),
        ],
        const SizedBox(height: 24),
        Text(
          rosterTitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        if (people.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                emptyRoster,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...people.map(
            (person) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(Icons.swap_horiz_rounded, color: accent, size: 20),
                ),
                title: Text(
                  personLabel(person),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade500),
                onTap: () => onTransferPerson(person),
              ),
            ),
          ),
      ],
    );
  }
}

class _TransferOptionCard extends StatelessWidget {
  const _TransferOptionCard({
    required this.accent,
    required this.option,
  });

  final Color accent;
  final _TransferOption option;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: option.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentTransferScreen extends StatefulWidget {
  const StudentTransferScreen({
    super.key,
    required this.kind,
    this.studentId,
  });

  final StudentTransferKind kind;
  final String? studentId;

  @override
  State<StudentTransferScreen> createState() => _StudentTransferScreenState();
}

class _StudentTransferScreenState extends State<StudentTransferScreen> {
  final _transfer = TransferService.instance;
  AdminStudentRecord? _selected;
  var _toGrade = '';
  var _toSection = '';
  AdminDriverRecord? _toDriver;
  String? _toCampus;
  var _busy = false;

  String get _schoolId => AuthService.activeSchoolId ?? 'TB-001';

  List<AdminStudentRecord> get _students =>
      StudentRegistryService.instance.studentsForSchool(_schoolId);

  List<AdminStudentRecord> get _eligibleStudents {
    if (widget.kind == StudentTransferKind.transport) {
      return _students.where((s) => s.transportEnabled).toList();
    }
    return _students;
  }

  AppStrings get s => AppLocale.instance.strings;

  String get _title => switch (widget.kind) {
        StudentTransferKind.section => s.transferSectionToSection,
        StudentTransferKind.grade => s.transferGradeToGrade,
        StudentTransferKind.transport => s.transferTransportToTransport,
        StudentTransferKind.campus => s.transferCampusToCampus,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSelection());
  }

  void _initSelection() {
    AdminStudentRecord? student;
    final id = widget.studentId;
    if (id != null) {
      student = StudentRegistryService.instance.lookupById(id);
    }
    student ??= _eligibleStudents.firstOrNull;
    if (student != null) {
      _applyStudent(student);
    }
  }

  void _applyStudent(AdminStudentRecord v) {
    setState(() {
      _selected = v;
      if (widget.kind == StudentTransferKind.section) {
        _toGrade = v.grade;
      } else if (widget.kind == StudentTransferKind.grade) {
        _toGrade = '';
      }
      _toSection = '';
      _toDriver = null;
      _toCampus = v.campus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final grades = ClassStructureService.instance.gradesForSchool();
    final campuses = SchoolRegistryService.instance.campusesForSchool(_schoolId);
    final drivers = DriverRegistryService.instance.driversForSchool(_schoolId);
    final sections = _toGrade.isEmpty
        ? <String>[]
        : ClassStructureService.instance.sectionsForGrade(_toGrade);

    if (_eligibleStudents.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AdminFormTheme.student.primary,
          title: Text(_title),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.kind == StudentTransferKind.transport
                  ? s.transferNoTransportStudents
                  : s.transferNoStudents,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminFormTheme.student.primary,
        title: Text(_title),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          _buildStudentPicker(),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            _CurrentPlacementCard(
              accent: AdminFormTheme.student.primary,
              rows: _currentRows(drivers),
            ),
            const SizedBox(height: 16),
            if (widget.kind == StudentTransferKind.campus) ...[
              _dropdown<String>(
                label: s.transferToCampus,
                value: _toCampus ?? campuses.firstOrNull,
                items: campuses,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _toCampus = v),
              ),
            ] else if (widget.kind == StudentTransferKind.transport) ...[
              _dropdown<AdminDriverRecord>(
                label: s.transferToBus,
                value: _toDriver,
                items: drivers
                    .where((d) => d.driverId != _selected!.transportId)
                    .toList(),
                itemLabel: (d) => '${d.busNumber} · ${d.fullName}',
                onChanged: (v) => setState(() => _toDriver = v),
              ),
            ] else if (grades.isNotEmpty) ...[
              _dropdown<String>(
                label: s.transferToGrade,
                value: _toGrade.isEmpty ? grades.firstOrNull : _toGrade,
                items: grades,
                itemLabel: (v) => v,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _toGrade = v;
                    _toSection = '';
                  });
                },
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: s.transferToSection,
                value: _toSection.isEmpty && sections.isNotEmpty
                    ? sections.first
                    : (_toSection.isEmpty ? null : _toSection),
                items: sections,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _toSection = v ?? ''),
              ),
            ],
            const SizedBox(height: 24),
            adminPrimaryButton(
              label: s.confirmTransfer,
              color: AdminFormTheme.student.primary,
              loading: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ],
      ),
    );
  }

  List<MapEntry<String, String>> _currentRows(List<AdminDriverRecord> drivers) {
    final student = _selected!;
    AdminDriverRecord? driver;
    for (final d in drivers) {
      if (d.driverId == student.transportId) {
        driver = d;
        break;
      }
    }
    return [
      MapEntry(s.grade, student.grade),
      MapEntry(s.section, _sectionLabel(student)),
      MapEntry(s.campus, student.campus),
      if (student.transportEnabled)
        MapEntry(
          AppLocale.instance.strings.dashboardTitle('transport', roleKey: 'admin'),
          driver != null ? '${driver.busNumber} (${driver.fullName})' : student.transportId ?? '—',
        ),
    ];
  }

  Widget _buildStudentPicker() {
    return _dropdown<AdminStudentRecord>(
      label: s.selectStudent,
      value: _selected ?? _eligibleStudents.firstOrNull,
      items: _eligibleStudents,
      itemLabel: (st) => '${st.fullName} · ${st.className}',
      onChanged: (v) {
        if (v == null) return;
        _applyStudent(v);
      },
    );
  }

  bool get _canSubmit {
    if (_selected == null || _busy) return false;
    return switch (widget.kind) {
      StudentTransferKind.campus => (_toCampus ?? '').trim().isNotEmpty,
      StudentTransferKind.transport => _toDriver != null,
      _ => _toGrade.isNotEmpty && _toSection.isNotEmpty,
    };
  }

  Future<void> _submit() async {
    final student = _selected!;
    setState(() => _busy = true);

    // Transport stays immediate (not in the approval workflow). Class / grade
    // / campus moves go through transfer_requests so Academic Admin / owner
    // can approve — owners auto-approve their own requests.
    if (widget.kind == StudentTransferKind.transport) {
      final ok = _transfer.transferStudentTransport(
        studentId: student.studentId,
        toDriverId: _toDriver!.driverId,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _finishSubmit(ok, applied: true);
      return;
    }

    String? error;
    if (widget.kind == StudentTransferKind.campus) {
      error = await TransferWorkflowService.instance.createCampusTransfer(
        studentId: student.studentId,
        toCampus: _toCampus!,
      );
    } else {
      error = await TransferWorkflowService.instance.createInternalTransfer(
        studentId: student.studentId,
        toGrade: _toGrade,
        toSection: _toSection,
        target: widget.kind == StudentTransferKind.grade
            ? InternalTransferTarget.grade
            : InternalTransferTarget.section,
      );
    }

    var applied = false;
    if (error == null && TransferPermissions.canApproveInternalTransfers) {
      final created =
          TransferWorkflowService.instance.requestsForSchool().first;
      final approveError = await TransferWorkflowService.instance
          .approveTransfer(created.id);
      if (approveError == null) {
        applied = true;
      } else if (approveError != 'self_approval_blocked') {
        error = approveError;
      }
    }

    if (!mounted) return;
    setState(() => _busy = false);
    _finishSubmit(error == null, applied: applied, errorCode: error);
  }

  void _finishSubmit(bool ok, {required bool applied, String? errorCode}) {
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            applied
                ? s.studentTransferred
                : 'Transfer request submitted — awaiting approval.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorCode == null
              ? s.transferFailed
              : 'Transfer failed ($errorCode).'),
        ),
      );
    }
  }

  String _sectionLabel(AdminStudentRecord student) {
    if (student.className.length > student.grade.length) {
      return student.className.substring(student.grade.length).trim();
    }
    return student.className;
  }
}

class TeacherTransferScreen extends StatefulWidget {
  const TeacherTransferScreen({
    super.key,
    required this.kind,
    this.teacherId,
  });

  final TeacherTransferKind kind;
  final String? teacherId;

  @override
  State<TeacherTransferScreen> createState() => _TeacherTransferScreenState();
}

class _TeacherTransferScreenState extends State<TeacherTransferScreen> {
  final _transfer = TransferService.instance;
  AdminTeacherRecord? _selected;
  String? _fromClassName;
  var _toGrade = '';
  var _toSection = '';
  String? _toCampus;
  var _busy = false;

  String get _schoolId => AuthService.activeSchoolId ?? 'TB-001';

  List<AdminTeacherRecord> get _teachers =>
      TeacherRegistryService.instance.staffTeachersForSchool(_schoolId);

  AppStrings get s => AppLocale.instance.strings;

  String get _title => switch (widget.kind) {
        TeacherTransferKind.section => s.transferSectionToSection,
        TeacherTransferKind.grade => s.transferGradeToGrade,
        TeacherTransferKind.campus => s.transferCampusToCampus,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSelection());
  }

  void _initSelection() {
    AdminTeacherRecord? teacher;
    final id = widget.teacherId;
    if (id != null) {
      teacher = TeacherRegistryService.instance.lookupById(id);
    }
    teacher ??= _teachers.firstOrNull;
    if (teacher != null) {
      _applyTeacher(teacher);
    }
  }

  void _applyTeacher(AdminTeacherRecord v) {
    final classNames = _classNamesFor(v);
    setState(() {
      _selected = v;
      _fromClassName = classNames.firstOrNull;
      _toGrade = widget.kind == TeacherTransferKind.section
          ? _gradeFromClass(_fromClassName ?? '')
          : '';
      _toSection = '';
      _toCampus = v.campus;
    });
  }

  List<String> _classNamesFor(AdminTeacherRecord teacher) {
    if (teacher.classAssignments.isNotEmpty) {
      return teacher.classAssignments.map((a) => a.className).toList();
    }
    return teacher.assignedClass
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  List<String> get _classNames {
    if (_selected == null) return const [];
    return _classNamesFor(_selected!);
  }

  @override
  Widget build(BuildContext context) {
    final grades = ClassStructureService.instance.gradesForSchool();
    final campuses = SchoolRegistryService.instance.campusesForSchool(_schoolId);
    final sections = _toGrade.isEmpty
        ? <String>[]
        : ClassStructureService.instance.sectionsForGrade(_toGrade);

    if (_teachers.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AdminFormTheme.teacher.primary,
          title: Text(_title),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              s.transferNoTeachers,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminFormTheme.teacher.primary,
        title: Text(_title),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          _dropdown<AdminTeacherRecord>(
            label: s.selectTeacher,
            value: _selected ?? _teachers.firstOrNull,
            items: _teachers,
            itemLabel: (t) => '${t.fullName} · ${t.assignedClass}',
            onChanged: (v) {
              if (v == null) return;
              _applyTeacher(v);
            },
          ),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            _CurrentPlacementCard(
              accent: AdminFormTheme.teacher.primary,
              rows: [
                MapEntry(s.assignedClasses, _selected!.assignedClass),
                MapEntry(s.campus, _selected!.campus),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.kind == TeacherTransferKind.campus) ...[
              _dropdown<String>(
                label: s.transferToCampus,
                value: _toCampus ?? campuses.firstOrNull,
                items: campuses,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _toCampus = v),
              ),
            ] else if (_classNames.isNotEmpty && grades.isNotEmpty) ...[
              _dropdown<String>(
                label: s.transferFromClass,
                value: _fromClassName ?? _classNames.firstOrNull,
                items: _classNames,
                itemLabel: (v) => v,
                onChanged: (v) {
                  setState(() {
                    _fromClassName = v;
                    if (widget.kind == TeacherTransferKind.section) {
                      _toGrade = _gradeFromClass(v ?? '');
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: s.transferToGrade,
                value: _toGrade.isEmpty ? grades.firstOrNull : _toGrade,
                items: grades,
                itemLabel: (v) => v,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _toGrade = v;
                    _toSection = '';
                  });
                },
              ),
              const SizedBox(height: 12),
              _dropdown<String>(
                label: s.transferToSection,
                value: _toSection.isEmpty && sections.isNotEmpty
                    ? sections.first
                    : (_toSection.isEmpty ? null : _toSection),
                items: sections,
                itemLabel: (v) => v,
                onChanged: (v) => setState(() => _toSection = v ?? ''),
              ),
            ],
            const SizedBox(height: 24),
            adminPrimaryButton(
              label: s.confirmTransfer,
              color: AdminFormTheme.teacher.primary,
              loading: _busy,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ],
      ),
    );
  }

  bool get _canSubmit {
    if (_selected == null || _busy) return false;
    return switch (widget.kind) {
      TeacherTransferKind.campus => (_toCampus ?? '').trim().isNotEmpty,
      _ => (_fromClassName ?? '').isNotEmpty &&
          _toGrade.isNotEmpty &&
          _toSection.isNotEmpty,
    };
  }

  Future<void> _submit() async {
    final teacher = _selected!;
    setState(() => _busy = true);
    var ok = false;
    switch (widget.kind) {
      case TeacherTransferKind.section:
        ok = await _transfer.transferTeacherSection(
          teacherId: teacher.teacherId,
          fromClassName: _fromClassName!,
          toGrade: _toGrade,
          toSection: _toSection,
        );
      case TeacherTransferKind.grade:
        ok = await _transfer.transferTeacherGrade(
          teacherId: teacher.teacherId,
          fromClassName: _fromClassName!,
          toGrade: _toGrade,
          toSection: _toSection,
        );
      case TeacherTransferKind.campus:
        ok = _transfer.transferTeacherCampus(
          teacherId: teacher.teacherId,
          toCampus: _toCampus!,
        );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.teacherTransferred),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transferFailed)),
      );
    }
  }

  String _gradeFromClass(String className) {
    for (final grade in ClassStructureService.instance.gradesForSchool()) {
      if (className.startsWith(grade)) return grade;
    }
    return className.split(' ').first;
  }
}

class DriverBusTransferScreen extends StatefulWidget {
  const DriverBusTransferScreen({super.key, this.fromDriverId});

  final String? fromDriverId;

  @override
  State<DriverBusTransferScreen> createState() => _DriverBusTransferScreenState();
}

class _DriverBusTransferScreenState extends State<DriverBusTransferScreen> {
  final _transfer = TransferService.instance;
  AdminDriverRecord? _fromDriver;
  AdminDriverRecord? _toDriver;
  var _busy = false;

  String get _schoolId => AuthService.activeSchoolId ?? 'TB-001';

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSelection());
  }

  void _initSelection() {
    final drivers =
        DriverRegistryService.instance.driversForSchool(_schoolId);
    AdminDriverRecord? from;
    final id = widget.fromDriverId;
    if (id != null) {
      from = DriverRegistryService.instance.lookupById(id);
    }
    from ??= drivers.firstOrNull;
    if (from != null) {
      setState(() => _fromDriver = from);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivers = DriverRegistryService.instance.driversForSchool(_schoolId);

    if (drivers.length < 2) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AdminFormTheme.driver.primary,
          title: Text(s.transferBusToBus),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              s.transferNeedTwoDrivers,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AdminFormTheme.driver.primary,
        title: Text(s.transferBusToBus),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          Text(
            s.transferBusToBusDescription,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 20),
          _dropdown<AdminDriverRecord>(
            label: s.transferFromBus,
            value: _fromDriver ?? drivers.firstOrNull,
            items: drivers,
            itemLabel: _driverLabel,
            onChanged: (v) => setState(() {
              _fromDriver = v;
              if (_toDriver?.driverId == v?.driverId) _toDriver = null;
            }),
          ),
          const SizedBox(height: 12),
          _dropdown<AdminDriverRecord>(
            label: s.transferToBus,
            value: _toDriver,
            items: drivers
                .where((d) => d.driverId != (_fromDriver?.driverId ?? ''))
                .toList(),
            itemLabel: _driverLabel,
            onChanged: (v) => setState(() => _toDriver = v),
          ),
          if (_fromDriver != null && _toDriver != null) ...[
            const SizedBox(height: 16),
            _CurrentPlacementCard(
              accent: AdminFormTheme.driver.primary,
              rows: [
                MapEntry(
                  s.transferFromBus,
                  '${_fromDriver!.busNumber} · ${_fromDriver!.routeName}',
                ),
                MapEntry(
                  s.transferToBus,
                  '${_toDriver!.busNumber} · ${_toDriver!.routeName}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          adminPrimaryButton(
            label: s.confirmTransfer,
            color: AdminFormTheme.driver.primary,
            loading: _busy,
            onPressed: _fromDriver != null && _toDriver != null && !_busy
                ? _submit
                : null,
          ),
        ],
      ),
    );
  }

  String _driverLabel(AdminDriverRecord d) =>
      '${d.fullName} · ${d.busNumber} · ${d.routeName}';

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = _transfer.transferDriverBus(
      fromDriverId: _fromDriver!.driverId,
      toDriverId: _toDriver!.driverId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.driverBusTransferred),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transferFailed)),
      );
    }
  }
}

class _CurrentPlacementCard extends StatelessWidget {
  const _CurrentPlacementCard({
    required this.accent,
    required this.rows,
  });

  final Color accent;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.currentPlacement,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      row.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _dropdown<T>({
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required ValueChanged<T?> onChanged,
}) {
  return InputDecorator(
    decoration: adminFieldDecoration(
      label: label,
      icon: Icons.list_alt_outlined,
      accent: Colors.indigo,
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
        isExpanded: true,
        hint: Text(label),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabel(item)),
              ),
            )
            .toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    ),
  );
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
