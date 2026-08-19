import 'package:mayabela/models/app_notification.dart';

/// User-facing notification categories (Settings toggles).
enum NotificationPreferenceKey {
  master,
  homework,
  messages,
  transport,
  announcements,
  grades,
  attendance,
  gallery,
  dailyActivity,
  fees,
  calendar,
}

NotificationPreferenceKey preferenceKeyForType(NotificationType type) {
  return switch (type) {
    NotificationType.homework => NotificationPreferenceKey.homework,
    NotificationType.message => NotificationPreferenceKey.messages,
    NotificationType.bus => NotificationPreferenceKey.transport,
    NotificationType.announcement => NotificationPreferenceKey.announcements,
    NotificationType.grade => NotificationPreferenceKey.grades,
    NotificationType.attendance => NotificationPreferenceKey.attendance,
    NotificationType.gallery => NotificationPreferenceKey.gallery,
    NotificationType.dailyActivity ||
    NotificationType.dailyActivitySeen =>
      NotificationPreferenceKey.dailyActivity,
    NotificationType.fee => NotificationPreferenceKey.fees,
    NotificationType.materialPurchase => NotificationPreferenceKey.fees,
    NotificationType.calendar => NotificationPreferenceKey.calendar,
    NotificationType.qrScan || NotificationType.general =>
      NotificationPreferenceKey.announcements,
  };
}
