import 'package:flutter/foundation.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Maps dashboard tile ids to unread notification counts for every role.
class DashboardBadgeService extends ChangeNotifier {
  DashboardBadgeService._();
  static final instance = DashboardBadgeService._();

  /// When a tile was last opened — badges hide older unread items per tile only.
  final Map<String, DateTime> _tileDismissedAt = {};

  static const _tileTypes = <String, List<NotificationType>>{
    'homework': [NotificationType.homework],
    'gallery': [NotificationType.gallery],
    'grades': [NotificationType.grade],
    'attendance': [NotificationType.attendance],
    'announcements': [NotificationType.announcement],
    'calendar': [NotificationType.calendar],
    'timetable': [NotificationType.calendar],
    'fees': [NotificationType.fee],
    'finance': [NotificationType.fee],
    'learning_materials': [NotificationType.materialPurchase],
    'learning_materials_admin': [NotificationType.materialPurchase],
    'staff_learning_materials': [NotificationType.materialPurchase],
    'bus': [NotificationType.bus],
    'transport': [NotificationType.bus],
    'route': [NotificationType.bus],
    'map': [NotificationType.bus],
    'passengers': [NotificationType.bus, NotificationType.qrScan],
    'scan': [NotificationType.qrScan, NotificationType.bus],
    'pickup': [NotificationType.qrScan, NotificationType.bus],
    'qr': [NotificationType.qrScan],
    'issue': [NotificationType.general],
    'classes': [
      NotificationType.dailyActivity,
      NotificationType.dailyActivitySeen,
      NotificationType.homework,
      NotificationType.grade,
      NotificationType.attendance,
    ],
    'children': [
      NotificationType.homework,
      NotificationType.grade,
      NotificationType.attendance,
      NotificationType.gallery,
      NotificationType.dailyActivity,
      NotificationType.fee,
      NotificationType.bus,
      NotificationType.calendar,
    ],
  };

  String _tileKey(String tileId, String? roleKey) {
    final role = roleKey ?? AuthService.currentUser?.roleKey ?? '';
    final school = AuthService.activeSchoolId ?? '';
    return '$school|$role|$tileId';
  }

  DateTime? _dismissedAt(String tileId, {String? roleKey}) =>
      _tileDismissedAt[_tileKey(tileId, roleKey)];

  int countFor(String tileId, {String? roleKey}) {
    if (tileId == 'settings') return 0;

    if (tileId == 'messages') {
      return _messageBadgeCount(roleKey);
    }

    if (tileId == 'parent_approvals') {
      EnrollmentService.instance.ensureSeeded();
      return EnrollmentService.instance.pendingCountForCurrentUser();
    }

    final types = _tileTypes[tileId];
    if (types == null || types.isEmpty) return 0;

    return NotificationService.instance.unreadCountForTypesSince(
      types,
      roleKey: roleKey,
      since: _dismissedAt(tileId, roleKey: roleKey),
    );
  }

  int _messageBadgeCount(String? roleKey) {
    final role = roleKey ?? AuthService.currentUser?.roleKey;
    final dismissedAt = _dismissedAt('messages', roleKey: roleKey);
    final chatUnread =
        SchoolDataService.instance.totalUnreadMessagesForRole(role);
    final alertUnread = NotificationService.instance.unreadCountForTypesSince(
      [NotificationType.message],
      roleKey: roleKey,
      since: dismissedAt,
    );
    return chatUnread + alertUnread;
  }

  void markReadForTile(String tileId, {String? roleKey}) {
    if (tileId == 'parent_approvals') {
      return;
    }

    _tileDismissedAt[_tileKey(tileId, roleKey)] = DateTime.now();

    if (tileId == 'messages') {
      NotificationService.instance.markMessagesBadgeRead(roleKey: roleKey);
    }

    notifyListeners();
  }

  void markReadForNotificationType(NotificationType type, {String? roleKey}) {
    final tileId = tileIdForNotificationType(type);
    if (tileId == null) return;
    markReadForTile(tileId, roleKey: roleKey);
  }

  void clearForLogout() {
    _tileDismissedAt.clear();
    notifyListeners();
  }

  /// Reverse lookup: which dashboard tile should clear when a notification opens.
  String? tileIdForNotificationType(NotificationType type) {
    return switch (type) {
      NotificationType.message => 'messages',
      NotificationType.homework => 'homework',
      NotificationType.gallery => 'gallery',
      NotificationType.grade => 'grades',
      NotificationType.attendance => 'attendance',
      NotificationType.announcement => 'announcements',
      NotificationType.calendar => 'calendar',
      NotificationType.fee => 'fees',
      NotificationType.materialPurchase => 'learning_materials',
      NotificationType.bus => 'bus',
      NotificationType.qrScan => 'qr',
      NotificationType.dailyActivity ||
      NotificationType.dailyActivitySeen =>
        AuthService.currentUser?.roleKey == AuthService.roleParent
            ? 'children'
            : 'classes',
      NotificationType.general => 'issue',
    };
  }
}
