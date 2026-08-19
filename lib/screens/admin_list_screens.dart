import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/admin_driver_screens.dart';
import 'package:mayabela/screens/admin_enrollment_screens.dart';
import 'package:mayabela/screens/admin_people_screens.dart';
import 'package:mayabela/screens/admin_transfer_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_credentials_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_staff_ui.dart';
import 'package:mayabela/widgets/invite_parent_actions.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

class AdminStudentsScreen extends StatelessWidget {
  const AdminStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final students = schoolId == null
        ? StudentRegistryService.instance.getAllStudents()
        : StudentRegistryService.instance.studentsForSchool(schoolId);

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(s.dashboardTitle('students', roleKey: 'admin')),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: s.scanStudentQr,
                onPressed: () async {
                  final studentId =
                      await showAdminScanStudentQrDialog(context);
                  if (studentId == null || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminStudentProfileScreen(
                        studentId: studentId,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.sms_outlined),
                tooltip: s.inviteBulkTitle,
                onPressed: () => showBulkParentInviteDialog(
                  context,
                  students: students,
                ),
              ),
            ],
          ),
          body: ListView.separated(
            padding: listPagePadding(context),
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(student.fullName[0]),
                  ),
                  title: Text(student.fullName),
                  subtitle: Text(
                    '${student.studentId} · ${student.grade} · ${student.className}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded),
                        tooltip: s.transferStudent,
                        onPressed: () => showStudentTransferKindPicker(
                          context,
                          studentId: student.studentId,
                        ),
                      ),
                      InviteParentButton(student: student, compact: true),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminStudentProfileScreen(
                          studentId: student.studentId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;

    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        StaffRegistryNotifier.instance,
      ]),
      builder: (context, _) {
        final teachers = (schoolId == null
                ? TeacherRegistryService.instance.getAllTeachers()
                : TeacherRegistryService.instance.teachersForSchool(schoolId))
            .where((t) => t.staffRoles.isEmpty)
            .toList();
        final employees =
            EmployeeRegistryService.instance.employeesForSchool(schoolId);
        final drivers =
            DriverRegistryService.instance.driversForSchool(schoolId);
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF283593),
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              s.dashboardTitle('staff', roleKey: 'admin'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF3949AB),
                      Color(0xFF5C6BC0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -16,
                      top: -8,
                      child: Icon(
                        Icons.groups_rounded,
                        size: 110,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.staffOverview,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.staffOverviewHint,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              StaffStatChip(
                                icon: Icons.school_rounded,
                                label: s.teachersTab,
                                value: '${teachers.length}',
                                color: StaffPalette.teachers.primary,
                              ),
                              const SizedBox(width: 10),
                              StaffStatChip(
                                icon: Icons.badge_outlined,
                                label: s.otherStaffTab,
                                value: '${employees.length}',
                                color: StaffPalette.employees.primary,
                              ),
                              const SizedBox(width: 10),
                              StaffStatChip(
                                icon: Icons.directions_bus_rounded,
                                label: s.driversTab,
                                value: '${drivers.length}',
                                color: StaffPalette.transport.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: const Color(0xFF283593),
                              unselectedLabelColor: Colors.white,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              tabs: [
                                Tab(text: s.teachersTab),
                                Tab(text: s.otherStaffTab),
                                Tab(text: s.driversTab),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _StaffTeachersTab(
                      teachers: teachers,
                      onChanged: _refresh,
                    ),
                    _StaffEmployeesTab(
                      employees: employees,
                      onChanged: _refresh,
                    ),
                    _StaffTransportTab(
                      drivers: drivers,
                      onChanged: _refresh,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StaffTeachersTab extends StatelessWidget {
  const _StaffTeachersTab({
    required this.teachers,
    required this.onChanged,
  });

  final List<AdminTeacherRecord> teachers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final palette = StaffPalette.teachers;

    return ListView(
      padding: listPagePadding(context),
      children: [
        if (ModuleAccess.canHireStaff)
          StaffAddBannerButton(
            label: s.addTeacher,
            palette: palette,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminAddTeacherScreen(
                    kind: AdminPersonKind.classroomTeacher,
                  ),
                ),
              ).then((_) => onChanged());
            },
          ),
        if (ModuleAccess.canHireStaff) const SizedBox(height: 16),
        if (teachers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                s.noTeachersInSection,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...teachers.map(
            (teacher) {
              final summary = classroomAssignmentSummary(teacher, s).trim();
              return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StaffMemberCard(
                palette: palette,
                name: teacher.fullName,
                staffId: teacher.teacherId,
                subtitle: summary.isEmpty ? teacher.assignedClass : summary,
                trailingChip: teacher.subject,
                avatar: StaffRegistryAvatar(
                  staffId: teacher.teacherId,
                  name: teacher.fullName,
                  radius: 28,
                  fallbackColor: palette.primary,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminTeacherProfileScreen(
                        teacherId: teacher.teacherId,
                      ),
                    ),
                  ).then((_) => onChanged());
                },
              ),
            );
            },
          ),
      ],
    );
  }
}

class _StaffEmployeesTab extends StatelessWidget {
  const _StaffEmployeesTab({
    required this.employees,
    required this.onChanged,
  });

  final List<EmployeeRecord> employees;
  final VoidCallback onChanged;

  Future<void> _showAddOrEdit(
    BuildContext context, [
    EmployeeRecord? existing,
  ]) async {
    if (!ModuleAccess.canHireStaff) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null || schoolId.trim().isEmpty) return;

    final name = TextEditingController(text: existing?.fullName ?? '');
    final title = TextEditingController(text: existing?.jobTitle ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final department = TextEditingController(text: existing?.department ?? '');

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null
              ? AppLocale.instance.strings.addStaffRecord
              : 'Edit staff record',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Job title'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: department,
                decoration:
                    const InputDecoration(labelText: 'Department (optional)'),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Record only — no app login is created.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null && existing.isActive)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'deactivate'),
              child: const Text('Deactivate'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || title.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx, 'save');
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (action == 'deactivate' && existing != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate staff record?'),
          content: Text('Remove ${existing.fullName} from the active list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok == true) {
        EmployeeRegistryService.instance.deactivateEmployee(existing.employeeId);
        onChanged();
      }
    } else if (action == 'save') {
      if (existing == null) {
        EmployeeRegistryService.instance.addEmployee(
          schoolId: schoolId,
          fullName: name.text,
          jobTitle: title.text,
          phone: phone.text,
          department: department.text,
        );
      } else {
        EmployeeRegistryService.instance.updateEmployee(
          existing.copyWith(
            fullName: name.text.trim(),
            jobTitle: title.text.trim(),
            phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
            department:
                department.text.trim().isEmpty ? null : department.text.trim(),
            clearPhone: phone.text.trim().isEmpty,
            clearDepartment: department.text.trim().isEmpty,
          ),
        );
      }
      onChanged();
    }
    name.dispose();
    title.dispose();
    phone.dispose();
    department.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final palette = StaffPalette.employees;

    return ListView(
      padding: listPagePadding(context),
      children: [
        if (ModuleAccess.canHireStaff)
          StaffAddBannerButton(
            label: s.addStaffRecord,
            palette: palette,
            onPressed: () => _showAddOrEdit(context),
          ),
        if (ModuleAccess.canHireStaff) const SizedBox(height: 16),
        if (employees.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                s.noEmployeeRecords,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...employees.map(
            (employee) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StaffMemberCard(
                palette: palette,
                name: employee.fullName,
                staffId: employee.employeeId,
                subtitle: [
                  employee.jobTitle,
                  if (employee.phone != null) employee.phone!,
                ].join(' · '),
                trailingChip: employee.department,
                onTap: ModuleAccess.canHireStaff
                    ? () => _showAddOrEdit(context, employee)
                    : () {},
                avatar: CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.primary.withValues(alpha: 0.15),
                  child: Text(
                    employee.fullName.isEmpty
                        ? '?'
                        : employee.fullName[0].toUpperCase(),
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StaffTransportTab extends StatelessWidget {
  const _StaffTransportTab({
    required this.drivers,
    required this.onChanged,
  });

  final List<AdminDriverRecord> drivers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final palette = StaffPalette.transport;

    return ListView(
      padding: listPagePadding(context),
      children: [
        StaffAddBannerButton(
          label: s.addTransportStaff,
          palette: palette,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAddDriverScreen(),
              ),
            ).then((_) => onChanged());
          },
        ),
        const SizedBox(height: 16),
        if (drivers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                s.noTransportStaff,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...drivers.map(
            (driver) {
              final creds = DriverCredentialsService.instance;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaffMemberCard(
                  palette: palette,
                  name: driver.fullName,
                  staffId: driver.driverId,
                  subtitle: driver.routeName,
                  trailingChip: driver.plateNumber,
                  extraChips: [
                    '${s.loginUsername}: ${creds.loginFor(driver)}',
                  ],
                  avatar: StaffRegistryAvatar(
                    staffId: driver.driverId,
                    name: driver.fullName,
                    radius: 28,
                    isDriver: true,
                    fallbackColor: palette.primary,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminDriverProfileScreen(
                          driverId: driver.driverId,
                        ),
                      ),
                    ).then((_) => onChanged());
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
