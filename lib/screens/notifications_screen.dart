import 'package:flutter/material.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/screens/announcements_screen.dart';
import 'package:mayabela/screens/calendar_screen.dart';
import 'package:mayabela/screens/gallery_screen.dart';
import 'package:mayabela/screens/grade_reports_screen.dart';
import 'package:mayabela/screens/homework_screen.dart';
import 'package:mayabela/screens/learning_materials_screen.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/localized_screen.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.homework:
        return Icons.assignment;
      case NotificationType.gallery:
        return Icons.photo_library;
      case NotificationType.dailyActivity:
      case NotificationType.dailyActivitySeen:
        return Icons.today;
      case NotificationType.attendance:
        return Icons.check_circle;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.grade:
        return Icons.bar_chart;
      case NotificationType.qrScan:
        return Icons.qr_code;
      case NotificationType.fee:
        return Icons.payment;
      case NotificationType.materialPurchase:
        return Icons.menu_book;
      case NotificationType.bus:
        return Icons.directions_bus;
      case NotificationType.calendar:
        return Icons.calendar_month;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Colors.orange;
      case NotificationType.homework:
        return Colors.cyan;
      case NotificationType.gallery:
        return Colors.purple;
      case NotificationType.dailyActivity:
      case NotificationType.dailyActivitySeen:
        return Colors.teal;
      case NotificationType.attendance:
        return Colors.green;
      case NotificationType.announcement:
        return Colors.red;
      case NotificationType.grade:
        return Colors.deepOrange;
      case NotificationType.qrScan:
        return Colors.black87;
      case NotificationType.fee:
        return Colors.indigo;
      case NotificationType.materialPurchase:
        return const Color(0xFF4527A0);
      case NotificationType.bus:
        return Colors.blue;
      case NotificationType.calendar:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  void _openItem(BuildContext context, AppNotification item) {
    NotificationService.instance.markRead(item.id);

    final tileId = DashboardBadgeService.instance.tileIdForNotificationType(
      item.type,
    );
    if (tileId != null) {
      DashboardBadgeService.instance.markReadForTile(tileId);
    }

    switch (item.type) {
      case NotificationType.message:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
        return;
      case NotificationType.homework:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomeworkScreen(
              mode: switch (AuthService.currentUser?.roleKey) {
                AuthService.roleParent => HomeworkViewMode.parent,
                AuthService.roleStudent => HomeworkViewMode.student,
                _ => HomeworkViewMode.teacher,
              },
            ),
          ),
        );
        return;
      case NotificationType.gallery:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryScreen(
              mode: AuthService.currentUser?.roleKey == AuthService.roleParent
                  ? GalleryViewMode.parent
                  : GalleryViewMode.teacher,
            ),
          ),
        );
        return;
      case NotificationType.grade:
        String? studentName;
        String? className;
        final studentId = item.targetStudentId;
        if (studentId != null) {
          final record = StudentRegistryService.instance.lookupById(studentId);
          studentName = record?.fullName ??
              (item.body.contains('\'')
                  ? item.body.split('\'').first
                  : null);
          className = record?.className;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GradeReportsScreen(
              view: switch (AuthService.currentUser?.roleKey) {
                AuthService.roleParent => GradeReportView.parent,
                AuthService.roleStudent => GradeReportView.student,
                _ => GradeReportView.teacher,
              },
              initialClass: className,
              initialStudentName: studentName,
            ),
          ),
        );
        return;
      case NotificationType.announcement:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
        );
        return;
      case NotificationType.calendar:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        );
        return;
      case NotificationType.materialPurchase:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LearningMaterialsScreen(
              mode: switch (AuthService.currentUser?.roleKey) {
                AuthService.roleParent => LearningMaterialsViewMode.parent,
                AuthService.roleStudent => LearningMaterialsViewMode.student,
                _ => LearningMaterialsViewMode.teacher,
              },
            ),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(item.body)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        return LocalizedScreen(
          builder: (context, s) {
            final service = NotificationService.instance;
            final items = service.notificationsForCurrentUser();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(s.notifications),
            actions: [
              if (items.any((item) => !item.isRead))
                TextButton(
                  onPressed: service.markAllRead,
                  child: Text(
                    s.markAllRead,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          body: items.isEmpty
              ? Center(child: Text(s.noNotificationsYet))
              : ListView.separated(
                  padding: listPagePadding(context, horizontal: 12, top: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final color = _colorForType(item.type);
                    return Card(
                      color: item.isRead ? null : color.withValues(alpha: 0.06),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(_iconForType(item.type), color: color, size: 20),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight:
                                item.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.body),
                            const SizedBox(height: 4),
                            Text(
                              '${item.fromName} · ${s.timeAgo(item.createdAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: item.isRead
                            ? null
                            : Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: () => _openItem(context, item),
                      ),
                    );
                  },
                ),
        );
          },
        );
      },
    );
  }
}
