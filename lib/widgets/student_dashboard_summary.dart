import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/student_profile_service.dart';
import 'package:mayabela/widgets/dashboard_welcome_card.dart';

class StudentDashboardSummary extends StatelessWidget {
  const StudentDashboardSummary({super.key});

  static const _accent = Color(0xFF1565C0);
  static const _accentLight = Color(0xFF42A5F5);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        StudentPortalSyncService.instance,
        NotificationService.instance,
      ]),
      builder: (context, _) {
        final profile = StudentProfileService.profileForCurrentUser();
        final sync = StudentPortalSyncService.instance;
        final data = SchoolDataService.instance;

        if (sync.isSyncing && profile == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (profile == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              sync.error ??
                  'Your student profile could not be loaded. Check your connection and try again.',
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          );
        }

        final homeworkCount = data.getHomeworkForParent().length;
        final gradeCount = data.getGradeReportsForParent().length;
        final announcementCount = data
            .getAnnouncementsForRole(AuthService.roleStudent)
            .length;
        final unreadNotifications = NotificationService.instance
            .unreadCount(roleKey: AuthService.roleStudent);
        final upcomingEvents = data
            .getVisibleCalendarEventsForRole(AuthService.roleStudent)
            .where((event) {
              final today = DateTime.now();
              final day = DateTime(today.year, today.month, today.day);
              final eventDay =
                  DateTime(event.date.year, event.date.month, event.date.day);
              return !eventDay.isBefore(day);
            })
            .take(3)
            .length;

        final schoolLine = '${profile.schoolName} · ${profile.schoolId}';
        final detailLines = <String>[
          '${profile.grade} · ${profile.className}',
          if (profile.section.isNotEmpty) 'Section ${profile.section}',
        ];

        return DashboardWelcomeCard(
          name: profile.fullName,
          accent: _accent,
          accentLight: _accentLight,
          schoolLine: schoolLine,
          statsSectionTitle: 'At a glance',
          leading: _StudentAvatar(profile: profile),
          detailLines: detailLines,
          chips: [
            DashboardStatChip(
              icon: Icons.assignment,
              label: '$homeworkCount homework',
              color: Colors.cyan,
            ),
            DashboardStatChip(
              icon: Icons.bar_chart,
              label: '$gradeCount grades',
              color: Colors.deepOrange,
            ),
            DashboardStatChip(
              icon: Icons.campaign,
              label: '$announcementCount updates',
              color: Colors.red,
            ),
            if (unreadNotifications > 0)
              DashboardStatChip(
                icon: Icons.notifications_active,
                label: '$unreadNotifications new',
                color: Colors.purple,
              ),
            if (upcomingEvents > 0)
              DashboardStatChip(
                icon: Icons.event,
                label: '$upcomingEvents events',
                color: Colors.indigo,
              ),
          ],
          footerLine: sync.isSyncing
              ? 'Syncing latest school data…'
              : sync.error ??
                  (sync.lastSyncedAt != null
                      ? 'Updated ${_formatTime(sync.lastSyncedAt!)}'
                      : null),
        );
      },
    );
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '${time.day}/${time.month} · '
        '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.profile});

  final StudentPortalProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.hasPhoto) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: FileImage(File(profile.photoPath!)),
      );
    }

    if (profile.hasSchoolLogo) {
      final logoUrl = profile.schoolLogoUrl?.trim();
      if (logoUrl != null && logoUrl.isNotEmpty) {
        return CircleAvatar(
          radius: 36,
          backgroundColor: StudentDashboardSummary._accent.withValues(alpha: 0.1),
          backgroundImage: NetworkImage(logoUrl),
        );
      }
      return CircleAvatar(
        radius: 36,
        backgroundColor: StudentDashboardSummary._accent.withValues(alpha: 0.1),
        backgroundImage: FileImage(File(profile.schoolLogoPath!)),
      );
    }

    return CircleAvatar(
      radius: 36,
      backgroundColor: StudentDashboardSummary._accent.withValues(alpha: 0.12),
      child: Text(
        profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: StudentDashboardSummary._accent,
        ),
      ),
    );
  }
}
