enum CalendarEventType { exam, holiday, meeting, sports, classEvent, other }

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.time,
    this.audience = 'All',
    this.isEthiopianHoliday = false,
    this.autoAnnounce = false,
    this.announcementPublished = false,
    this.announcementReminderPublished = false,
  });

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final CalendarEventType type;
  final String? time;
  final String audience;
  final bool isEthiopianHoliday;
  final bool autoAnnounce;
  bool announcementPublished;
  bool announcementReminderPublished;

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? date,
    CalendarEventType? type,
    String? time,
    bool clearTime = false,
    String? audience,
    bool? isEthiopianHoliday,
    bool? autoAnnounce,
    bool? announcementPublished,
    bool? announcementReminderPublished,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      time: clearTime ? null : (time ?? this.time),
      audience: audience ?? this.audience,
      isEthiopianHoliday: isEthiopianHoliday ?? this.isEthiopianHoliday,
      autoAnnounce: autoAnnounce ?? this.autoAnnounce,
      announcementPublished:
          announcementPublished ?? this.announcementPublished,
      announcementReminderPublished: announcementReminderPublished ??
          this.announcementReminderPublished,
    );
  }
}

enum QrScanAction { entry, exit, present, late, absent }

class QrScanRecord {
  QrScanRecord({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.action,
    required this.time,
    required this.scannedBy,
  });

  final String studentId;
  final String studentName;
  final String className;
  final QrScanAction action;
  final DateTime time;
  final String scannedBy;
}

class StudentQrProfile {
  StudentQrProfile({
    required this.id,
    required this.name,
    required this.className,
    required this.qrCode,
  });

  final String id;
  final String name;
  final String className;
  final String qrCode;
}
