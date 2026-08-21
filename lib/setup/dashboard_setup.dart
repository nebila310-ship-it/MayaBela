import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/screens/admin_enrollment_screens.dart';
import 'package:mayabela/screens/announcements_screen.dart';
import 'package:mayabela/screens/attendance_screen.dart';
import 'package:mayabela/screens/bus_tracking_screen.dart';
import 'package:mayabela/screens/transport_live_map_screen.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/screens/transport_screens.dart';
import 'package:mayabela/screens/transport_qr_scanner_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/class_timetable_screen.dart';
import 'package:mayabela/screens/fees_payments_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/learning_materials_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/screens/parent_student_affairs_screen.dart';
import 'package:mayabela/screens/teacher_student_affairs_screen.dart';
import 'package:mayabela/screens/maya_assistant_screen.dart';
import 'package:mayabela/widgets/parent_child_picker.dart';
import 'package:mayabela/screens/my_classes_screen.dart';
import 'package:mayabela/screens/qr_entry_exit_screen.dart';
import 'package:mayabela/screens/settings_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_navigation_store.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/screens/student_profile_screen.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/widgets/parent_bus_link_card.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/widgets/report_issue_dialog.dart';
import 'package:mayabela/widgets/dashboard_card.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/shell/web_erp_open_route.dart';

String _t(String id, String roleKey) =>
    AppLocale.instance.strings.dashboardTitle(id, roleKey: roleKey);

int _badge(String tileId) => DashboardBadgeService.instance.countFor(tileId);

void _openTile(String tileId, VoidCallback action) {
  DashboardBadgeService.instance.markReadForTile(tileId);
  action();
}

DashboardEntry _mayaAssistantEntry(
  String role, {
  bool Function()? isVisible,
}) {
  const color = Color(0xFF0F766E);
  return DashboardEntry(
    id: 'maya_assistant',
    icon: Icons.auto_awesome,
    color: color,
    isVisible: isVisible,
    builder: (context) => DashboardCard(
      icon: Icons.auto_awesome,
      title: _t('maya_assistant', role),
      color: color,
      onTap: () => _openTile('maya_assistant', () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MayaAssistantScreen(roleKey: role),
          ),
        );
      }),
    ),
  );
}

void registerAllDashboards() {
  DashboardRegistry.registerTeacherEntries(_teacherEntries());
  final erpTiles = _erpAlignedEntries();
  DashboardRegistry.registerStaffEntries(erpTiles);
  DashboardRegistry.registerParentEntries(_parentEntries());
  DashboardRegistry.registerStudentEntries(_studentEntries());
  DashboardRegistry.registerAdminEntries(erpTiles);
  DashboardRegistry.registerDriverEntries(_driverEntries());
}

const _erpTileColors = <Color>[
  Color(0xFF4527A0),
  Color(0xFF1565C0),
  Color(0xFF00897B),
  Color(0xFFEF6C00),
  Color(0xFF3949AB),
  Color(0xFF6A1B9A),
  Color(0xFF2E7D32),
  Color(0xFFC62828),
];

/// Fallback admin/staff tiles share the web ERP catalog so they cannot drift.
List<DashboardEntry> _erpAlignedEntries() {
  final items = webErpAllNavItems()
      .where((item) => item.id != 'dashboard' && !item.isLogout)
      .toList(growable: false);
  final entries = <DashboardEntry>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final color = _erpTileColors[i % _erpTileColors.length];
    entries.add(
      DashboardEntry(
        id: item.id,
        icon: item.icon,
        color: color,
        isVisible: () => ModuleAccess.canView(item.id),
        builder: (context) => DashboardCard(
          icon: item.icon,
          title: item.label,
          color: color,
          badgeCount: item.badgeId == null ? 0 : _badge(item.badgeId!),
          onTap: () => _openTile(item.id, () {
            webErpOpenRoute(context, item.id);
          }),
        ),
      ),
    );
  }
  return entries;
}

List<DashboardSectionDefinition> _erpSectionDefinitions() {
  final items = webErpModuleNavItemsForCurrentUser();
  final sections = <String>[];
  for (final item in items) {
    final section = item.section ?? 'Modules';
    if (!sections.contains(section)) {
      sections.add(section);
    }
  }
  return [
    for (final section in sections)
      DashboardSectionDefinition(
        title: section,
        icon: webErpIconForSection(section),
        entryIds: items
            .where((item) => (item.section ?? 'Modules') == section)
            .map((item) => item.id)
            .toList(growable: false),
      ),
  ];
}

List<DashboardEntry> _teacherEntries() {
  final access = TeacherAccessService.instance;
  final teacherName = AuthService.displayNameForRole(AuthService.roleTeacher);
  const role = AuthService.roleTeacher;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MessagesScreen(
            canCompose: true,
            composeScope: MessageComposeScope.teacher,
          ),
        ),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'classes',
      icon: Icons.class_,
      color: Colors.blue,
      isVisible: () => access.canAccessTeacherDashboardTile('classes'),
      builder: (context) => DashboardCard(
        icon: Icons.class_,
        title: _t('classes', role),
        color: Colors.blue,
        badgeCount: _badge('classes'),
        onTap: () => _openTile('classes', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyClassesScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      isVisible: () => access.canAccessTeacherDashboardTile('attendance'),
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      isVisible: () => access.canAccessTeacherDashboardTile('messages'),
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      isVisible: () => access.canAccessTeacherDashboardTile('announcements'),
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(
                canCreate: access.canCreateAnnouncements,
                authorName: teacherName,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      isVisible: () => access.canAccessTeacherDashboardTile('homework'),
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeworkScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      isVisible: () =>
          access.canAccessTeacherDashboardTile('learning_materials'),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        badgeCount: _badge('learning_materials'),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'gallery',
      icon: Icons.photo_library,
      color: Colors.purple,
      isVisible: () => access.canAccessTeacherDashboardTile('gallery'),
      builder: (context) => DashboardCard(
        icon: Icons.photo_library,
        title: _t('gallery', role),
        color: Colors.purple,
        badgeCount: _badge('gallery'),
        onTap: () => _openTile('gallery', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GalleryScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      isVisible: () => access.canAccessTeacherDashboardTile('grades'),
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(
                view: GradeReportView.teacher,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'qr',
      icon: Icons.qr_code_scanner,
      color: Colors.black,
      isVisible: () => access.canAccessTeacherDashboardTile('qr'),
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_scanner,
        title: _t('qr', role),
        color: Colors.black,
        badgeCount: _badge('qr'),
        onTap: () => _openTile('qr', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QrEntryExitScreen(role: QrScreenRole.teacher),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.teal,
      isVisible: () => access.canAccessTeacherDashboardTile('calendar'),
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.teal,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.calendar_view_week,
      color: Colors.brown,
      isVisible: () => access.canAccessTeacherDashboardTile('timetable'),
      builder: (context) => DashboardCard(
        icon: Icons.calendar_view_week,
        title: _t('timetable', role),
        color: Colors.brown,
        badgeCount: _badge('timetable'),
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.teacher,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'parent_approvals',
      icon: Icons.how_to_reg,
      color: Colors.orange,
      isVisible: () =>
          access.hasAnyHomeroomClass ||
          ModuleAccess.canManage('parents'),
      builder: (context) => DashboardCard(
        icon: Icons.how_to_reg,
        title: _t('parent_approvals', role),
        color: Colors.orange,
        badgeCount: _badge('parent_approvals'),
        onTap: () => _openTile('parent_approvals', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParentApprovalsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'student_affairs',
      icon: Icons.balance_outlined,
      color: const Color(0xFF8E24AA),
      builder: (context) => DashboardCard(
        icon: Icons.balance_outlined,
        title: _t('student_affairs', role),
        color: const Color(0xFF8E24AA),
        badgeCount: _badge('student_affairs'),
        onTap: () => _openTile('student_affairs', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherStudentAffairsScreen(),
            ),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(
      role,
      isVisible: () => access.canAccessTeacherDashboardTile('maya_assistant'),
    ),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _parentEntries() {
  const role = AuthService.roleParent;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'children',
      icon: Icons.child_care,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.child_care,
        title: _t('children', role),
        color: Colors.teal,
        badgeCount: _badge('children'),
        onTap: () => _openTile('children', () => openParentChildHub(context)),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () => openParentAttendance(context)),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeworkScreen(mode: HomeworkViewMode.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        badgeCount: _badge('learning_materials'),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(
                mode: LearningMaterialsViewMode.parent,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'student_affairs',
      icon: Icons.balance_outlined,
      color: const Color(0xFF8E24AA),
      builder: (context) => DashboardCard(
        icon: Icons.balance_outlined,
        title: _t('student_affairs', role),
        color: const Color(0xFF8E24AA),
        badgeCount: _badge('student_affairs'),
        onTap: () => _openTile('student_affairs', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ParentStudentAffairsScreen(),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'fees',
      icon: Icons.payment,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.payment,
        title: _t('fees', role),
        color: Colors.indigo,
        badgeCount: _badge('fees'),
        onTap: () => _openTile('fees', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const FeesPaymentsScreen(view: FeesView.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'bus',
      icon: Icons.directions_bus,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.directions_bus,
        title: _t('bus', role),
        color: Colors.blue,
        badgeCount: _badge('bus'),
        onTap: () => _openTile('bus', () async {
          final child = await showParentChildPicker(
            context,
            title: AppLocale.instance.strings.busTracking,
            subtitle: AppLocale.instance.strings.chooseChildSubtitle,
          );
          if (child == null || !context.mounted) return;
          final driverId = child.studentId != null
              ? TransportService.instance.driverIdForStudent(child.studentId!)
              : TransportService.instance.driverIdForChildName(child.name);
          if (driverId == null) {
            final resolvedStudentId = child.studentId ??
                StudentRegistryService.instance
                    .lookupByName(child.name)
                    ?.studentId;
            if (resolvedStudentId != null && context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParentBusLinkScreen(
                    studentId: resolvedStudentId,
                    childName: child.name,
                  ),
                ),
              );
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocale.instance.strings.inviteParentNoRecord),
                ),
              );
            }
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransportLiveMapScreen(
                driverId: driverId,
                childName: child.name,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(view: GradeReportView.parent),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.calendar_view_week,
      color: Colors.brown,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_view_week,
        title: _t('timetable', role),
        color: Colors.brown,
        badgeCount: _badge('timetable'),
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.parent,
              ),
            ),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _studentEntries() {
  const role = AuthService.roleStudent;
  final settings = StudentAccountService.instance.settingsForSchool(
    AuthService.activeSchoolId,
  );

  return [
    DashboardEntry(
      id: 'profile',
      icon: Icons.person_outline,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.person_outline,
        title: _t('profile', role),
        color: Colors.blueGrey,
        onTap: () => _openTile('profile', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'grades',
      icon: Icons.bar_chart,
      color: Colors.deepOrange,
      builder: (context) => DashboardCard(
        icon: Icons.bar_chart,
        title: _t('grades', role),
        color: Colors.deepOrange,
        badgeCount: _badge('grades'),
        onTap: () => _openTile('grades', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const GradeReportsScreen(view: GradeReportView.student),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'homework',
      icon: Icons.assignment,
      color: Colors.cyan,
      builder: (context) => DashboardCard(
        icon: Icons.assignment,
        title: _t('homework', role),
        color: Colors.cyan,
        badgeCount: _badge('homework'),
        onTap: () => _openTile('homework', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeworkScreen(mode: HomeworkViewMode.student),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'learning_materials',
      icon: Icons.menu_book,
      color: const Color(0xFF4527A0),
      builder: (context) => DashboardCard(
        icon: Icons.menu_book,
        title: _t('learning_materials', role),
        color: const Color(0xFF4527A0),
        onTap: () => _openTile('learning_materials', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const LearningMaterialsScreen(
                mode: LearningMaterialsViewMode.student,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'attendance',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('attendance', role),
        color: Colors.green,
        badgeCount: _badge('attendance'),
        onTap: () => _openTile('attendance', () => openStudentAttendance(context)),
      ),
    ),
    DashboardEntry(
      id: 'timetable',
      icon: Icons.schedule,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.schedule,
        title: _t('timetable', role),
        color: Colors.indigo,
        onTap: () => _openTile('timetable', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClassTimetableScreen(
                mode: TimetableViewMode.student,
                readOnly: true,
              ),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.orange,
      isVisible: () => settings.allowStudentMessaging,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.orange,
        badgeCount: _badge('messages'),
        onTap: () => _openTile('messages', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MessagesScreen()),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.blueGrey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<DashboardEntry> _driverEntries() {
  const role = AuthService.roleDriver;

  void openMessages(BuildContext context) {
    _openTile('messages', () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MessagesScreen()),
      );
    });
  }

  void openRoute(BuildContext context) {
    _openTile('route', () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BusTrackingScreen(view: BusTrackingView.driver),
        ),
      );
    });
  }

  void openPassengers(BuildContext context) {
    _openTile('passengers', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportPassengerListScreen(driverId: driverId),
        ),
      );
    });
  }

  void openTransportScan(BuildContext context, {bool discharge = false}) {
    _openTile(discharge ? 'pickup' : 'scan', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportQrScannerScreen(
            driverId: driverId,
            initialMode: discharge
                ? TransportScanMode.discharge
                : TransportScanMode.onboard,
          ),
        ),
      );
    });
  }

  void openQr(BuildContext context) {
    _openTile('qr', () => openTransportScan(context));
  }

  void openLiveMap(BuildContext context) {
    _openTile('map', () {
      final driverId = TransportService.instance.linkedDriverId;
      if (driverId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.instance.strings.transportNoAssignedBus),
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportLiveMapScreen(
            driverId: driverId,
            autoStartDriverSharing: true,
          ),
        ),
      );
    });
  }

  return [
    DashboardEntry(
      id: 'route',
      icon: Icons.route,
      color: Colors.orange,
      builder: (context) => DashboardCard(
        icon: Icons.route,
        title: _t('route', role),
        color: Colors.orange,
        badgeCount: _badge('route'),
        onTap: () => openRoute(context),
      ),
    ),
    DashboardEntry(
      id: 'passengers',
      icon: Icons.people,
      color: Colors.blue,
      builder: (context) => DashboardCard(
        icon: Icons.people,
        title: _t('passengers', role),
        color: Colors.blue,
        badgeCount: _badge('passengers'),
        onTap: () => openPassengers(context),
      ),
    ),
    DashboardEntry(
      id: 'scan',
      icon: Icons.qr_code_scanner,
      color: Colors.black,
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_scanner,
        title: _t('scan', role),
        color: Colors.black,
        badgeCount: _badge('scan'),
        onTap: () => openTransportScan(context),
      ),
    ),
    DashboardEntry(
      id: 'qr',
      icon: Icons.qr_code_2,
      color: Colors.blueGrey,
      builder: (context) => DashboardCard(
        icon: Icons.qr_code_2,
        title: _t('qr', role),
        color: Colors.blueGrey,
        badgeCount: _badge('qr'),
        onTap: () => openQr(context),
      ),
    ),
    DashboardEntry(
      id: 'pickup',
      icon: Icons.check_circle,
      color: Colors.green,
      builder: (context) => DashboardCard(
        icon: Icons.check_circle,
        title: _t('pickup', role),
        color: Colors.green,
        badgeCount: _badge('pickup'),
        onTap: () => openTransportScan(context, discharge: true),
      ),
    ),
    DashboardEntry(
      id: 'messages',
      icon: Icons.message,
      color: Colors.indigo,
      builder: (context) => DashboardCard(
        icon: Icons.message,
        title: _t('messages', role),
        color: Colors.indigo,
        badgeCount: _badge('messages'),
        onTap: () => openMessages(context),
      ),
    ),
    DashboardEntry(
      id: 'announcements',
      icon: Icons.campaign,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.campaign,
        title: _t('announcements', role),
        color: Colors.red,
        badgeCount: _badge('announcements'),
        onTap: () => _openTile('announcements', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementsScreen(canCreate: false),
            ),
          );
        }),
      ),
    ),
    DashboardEntry(
      id: 'issue',
      icon: Icons.warning,
      color: Colors.red,
      builder: (context) => DashboardCard(
        icon: Icons.warning,
        title: _t('issue', role),
        color: Colors.red,
        badgeCount: _badge('issue'),
        onTap: () => _openTile('issue', () => ReportIssueDialog.showTransport(context)),
      ),
    ),
    DashboardEntry(
      id: 'map',
      icon: Icons.map,
      color: Colors.teal,
      builder: (context) => DashboardCard(
        icon: Icons.map,
        title: _t('map', role),
        color: Colors.teal,
        badgeCount: _badge('map'),
        onTap: () => openLiveMap(context),
      ),
    ),
    DashboardEntry(
      id: 'calendar',
      icon: Icons.calendar_month,
      color: Colors.purple,
      builder: (context) => DashboardCard(
        icon: Icons.calendar_month,
        title: _t('calendar', role),
        color: Colors.purple,
        badgeCount: _badge('calendar'),
        onTap: () => _openTile('calendar', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
        }),
      ),
    ),
    _mayaAssistantEntry(role),
    DashboardEntry(
      id: 'settings',
      icon: Icons.settings,
      color: Colors.grey,
      builder: (context) => DashboardCard(
        icon: Icons.settings,
        title: _t('settings', role),
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    ),
  ];
}

List<Widget> buildOrderedDashboardCards(String roleKey, BuildContext context) {
  DashboardNavigationStore.instance.clearRole(roleKey);
  final defaults = DashboardRegistry.defaultOrderFor(roleKey);
  final order = UserPreferencesService.instance.getOrder(roleKey, defaults);
  return order
      .map((id) => DashboardRegistry.find(roleKey, id))
      .whereType<DashboardEntry>()
      .where(DashboardRegistry.shouldShow)
      .map(
        (entry) => DashboardNavigationStore.instance.wrapTile(
          roleKey: roleKey,
          entryId: entry.id,
          child: entry.builder(context),
        ),
      )
      .toList();
}

List<DashboardSectionDefinition> sectionDefinitionsFor(String roleKey) {
  return switch (roleKey) {
    AuthService.roleAdmin || AuthService.roleStaff => _erpSectionDefinitions(),
    AuthService.roleTeacher => [
        const DashboardSectionDefinition(
          title: 'My classroom',
          icon: Icons.class_,
          entryIds: ['classes', 'attendance', 'parent_approvals', 'student_affairs'],
        ),
        const DashboardSectionDefinition(
          title: 'Teaching tools',
          icon: Icons.menu_book,
          entryIds: ['homework', 'grades', 'timetable', 'learning_materials', 'gallery', 'qr'],
        ),
        const DashboardSectionDefinition(
          title: 'Communication',
          icon: Icons.forum,
          entryIds: ['messages', 'announcements', 'calendar'],
        ),
        const DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        const DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleParent => const [
        DashboardSectionDefinition(
          title: 'My children',
          icon: Icons.child_care,
          entryIds: ['children', 'attendance', 'homework', 'learning_materials', 'grades', 'timetable'],
        ),
        DashboardSectionDefinition(
          title: 'School updates',
          icon: Icons.campaign,
          entryIds: ['messages', 'announcements', 'calendar'],
        ),
        DashboardSectionDefinition(
          title: 'Services',
          icon: Icons.miscellaneous_services,
          entryIds: ['student_affairs', 'fees', 'bus'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleDriver => const [
        DashboardSectionDefinition(
          title: 'On the road',
          icon: Icons.route,
          entryIds: ['route', 'map', 'passengers'],
        ),
        DashboardSectionDefinition(
          title: 'Student check-in',
          icon: Icons.qr_code_scanner,
          entryIds: ['scan', 'pickup', 'qr'],
        ),
        DashboardSectionDefinition(
          title: 'Communication',
          icon: Icons.forum,
          entryIds: ['messages', 'announcements', 'issue', 'calendar'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    AuthService.roleStudent => const [
        DashboardSectionDefinition(
          title: 'My school',
          icon: Icons.school_outlined,
          entryIds: ['profile', 'grades', 'homework', 'learning_materials', 'attendance', 'timetable'],
        ),
        DashboardSectionDefinition(
          title: 'Updates',
          icon: Icons.campaign,
          entryIds: ['announcements', 'calendar', 'messages'],
        ),
        DashboardSectionDefinition(
          title: 'Assistant',
          icon: Icons.auto_awesome,
          entryIds: ['maya_assistant'],
        ),
        DashboardSectionDefinition(
          title: 'Account',
          icon: Icons.tune,
          entryIds: ['settings'],
        ),
      ],
    _ => const [],
  };
}

List<BuiltDashboardSection> buildGroupedDashboardSections(
  String roleKey,
  BuildContext context,
) {
  final defaults = DashboardRegistry.defaultOrderFor(roleKey);
  final order = UserPreferencesService.instance.getOrder(roleKey, defaults);
  final widgetsById = <String, Widget>{};
  DashboardNavigationStore.instance.clearRole(roleKey);
  for (final id in order) {
    final entry = DashboardRegistry.find(roleKey, id);
    if (entry != null && DashboardRegistry.shouldShow(entry)) {
      widgetsById[id] = DashboardNavigationStore.instance.wrapTile(
        roleKey: roleKey,
        entryId: entry.id,
        child: entry.builder(context),
      );
    }
  }

  final built = <BuiltDashboardSection>[];
  for (final section in sectionDefinitionsFor(roleKey)) {
    final cards = section.entryIds
        .where(widgetsById.containsKey)
        .map((id) => widgetsById[id]!)
        .toList();
    if (cards.isEmpty) continue;
    built.add(
      BuiltDashboardSection(
        title: section.title,
        icon: section.icon,
        cards: cards,
      ),
    );
  }
  return built;
}

Future<void> openParentAttendance(BuildContext context) async {
  final children = SchoolDataService.instance.getChildren();
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No linked children found')),
    );
    return;
  }

  ChildProfile selected;
  if (children.length == 1) {
    selected = children.first;
  } else {
    final picked = await showModalBottomSheet<ChildProfile>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocale.instance.strings.dashboardTitle('attendance', roleKey: 'parent'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a child',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...children.map(
                (child) => ListTile(
                  leading: CircleAvatar(
                    child: Text(child.name.isNotEmpty ? child.name[0] : '?'),
                  ),
                  title: Text(child.name),
                  subtitle: Text('${child.className} · ${child.grade}'),
                  onTap: () => Navigator.pop(context, child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    selected = picked;
  }

  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceScreen(
        readOnly: true,
        childName: selected.name,
        initialClass: selected.className,
      ),
    ),
  );
}

Future<void> openStudentAttendance(BuildContext context) async {
  final children = SchoolDataService.instance.getChildren();
  if (children.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your attendance record is not available yet.'),
      ),
    );
    return;
  }

  final selected = children.first;
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceScreen(
        readOnly: true,
        childName: selected.name,
        initialClass: selected.className,
      ),
    ),
  );
}
