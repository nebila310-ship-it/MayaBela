import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/setup/dashboard_setup.dart';
import 'package:mayabela/widgets/adaptive_dashboard_shell.dart';
import 'package:mayabela/widgets/dashboard_welcome_card.dart';
import 'package:mayabela/widgets/teacher_profile_avatar.dart';

class RoleDashboardShell extends StatelessWidget {
  const RoleDashboardShell({
    super.key,
    required this.roleKey,
    required this.portalKind,
    required this.gradientColors,
    required this.welcomeEmoji,
    this.groupedLayout = false,
    this.header,
  });

  final String roleKey;
  final String portalKind;
  final List<Color> gradientColors;
  final String welcomeEmoji;
  final bool groupedLayout;
  final Widget? header;

  String _portalTitle(AppStrings s, String schoolName) {
    return switch (portalKind) {
      'teacher' => s.teacherPortalTitle(schoolName),
      'staff' => s.staffPortalTitle(schoolName),
      'parent' => s.parentPortalTitle(schoolName),
      'admin' => s.adminPortalTitle(schoolName),
      'driver' => s.driverPortalTitle(schoolName),
      'student' => s.studentPortalTitle(schoolName),
      _ => schoolName,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        NotificationService.instance,
        DashboardBadgeService.instance,
        UserPreferencesService.instance,
        StaffRegistryNotifier.instance,
        StudentPortalSyncService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final name = roleKey == AuthService.roleTeacher
            ? TeacherAccessService.instance.teacherName
            : roleKey == AuthService.roleStaff
                ? (AuthService.currentUser?.fullName ??
                    AuthService.displayNameForRole(AuthService.roleTeacher))
                : AuthService.displayNameForRole(roleKey);
        final schoolName = s.schoolName(AuthService.activeSchoolId);
        final schoolId = AuthService.activeSchoolId;
        final subtitle = schoolId != null ? '$schoolName · $schoolId' : schoolName;

        return AdaptiveDashboardShell(
          title: _portalTitle(s, schoolName),
          welcomeMessage: '${s.welcomeBack}, $name',
          welcomeGreeting: s.welcomeBack,
          welcomeName: name,
          welcomeSubtitle: subtitle,
          welcomeEmoji: welcomeEmoji,
          welcomeLeading: roleKey == AuthService.roleTeacher ||
                  roleKey == AuthService.roleStaff
              ? TeacherProfileAvatar(
                  name: name,
                  radius: 28,
                )
              : null,
          gradientColors: gradientColors,
          roleKey: roleKey,
          header: header ?? dashboardSummaryForRole(roleKey),
          hideWelcomeBanner: true,
          hideBrandingBanner: true,
          sections: groupedLayout
              ? buildGroupedDashboardSections(roleKey, context)
              : null,
          cards: groupedLayout
              ? const []
              : buildOrderedDashboardCards(roleKey, context),
        );
      },
    );
  }
}
