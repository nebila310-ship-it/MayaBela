enum NotificationType {
  message,
  homework,
  gallery,
  dailyActivity,
  dailyActivitySeen,
  attendance,
  announcement,
  grade,
  qrScan,
  fee,
  bus,
  calendar,
  materialPurchase,
  general,
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.fromRole,
    required this.fromName,
    required this.recipientRole,
    required this.createdAt,
    this.showOnMessagesBadge = true,
    this.isRead = false,
    this.targetStudentId,
    this.targetClassName,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String fromRole;
  final String fromName;
  final String recipientRole;
  final DateTime createdAt;
  final bool showOnMessagesBadge;
  bool isRead;
  /// When set, parent accounts only see this if they are linked to the student.
  final String? targetStudentId;

  /// When set, parent/student accounts only see this if a linked child is
  /// in this class (`5B` and `Grade 5B` match).
  final String? targetClassName;
}
