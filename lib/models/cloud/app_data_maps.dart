import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/models/fee_record.dart';
import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// Firestore / LocalJsonStore serialization for app content models.
abstract final class AppDataMaps {
  // —— Fees ——

  static Map<String, dynamic> feeToMap(FeeRecord fee) => {
        'id': fee.id,
        'studentName': fee.studentName,
        if (fee.studentId != null) 'studentId': fee.studentId,
        if (fee.className != null) 'className': fee.className,
        'title': fee.title,
        'amount': fee.amount,
        'dueDate': fee.dueDate.toIso8601String(),
        'term': fee.term,
        'status': fee.status.name,
        if (fee.paidVia != null) 'paidVia': fee.paidVia,
        if (fee.paidDate != null) 'paidDate': fee.paidDate!.toIso8601String(),
      };

  static FeeRecord feeFromMap(Map<String, dynamic> map) => FeeRecord(
        id: map['id'] as String,
        studentName: map['studentName'] as String,
        studentId: (map['studentId'] as String?)?.trim().isEmpty ?? true
            ? null
            : (map['studentId'] as String).trim().toUpperCase(),
        className: (map['className'] as String?)?.trim().isEmpty ?? true
            ? null
            : (map['className'] as String).trim(),
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        dueDate: DateTime.parse(map['dueDate'] as String),
        term: map['term'] as String? ?? '',
        status: FeeStatus.values.byName(map['status'] as String? ?? 'pending'),
        paidVia: map['paidVia'] as String?,
        paidDate: map['paidDate'] != null
            ? DateTime.tryParse(map['paidDate'] as String)
            : null,
      );

  // —— Calendar ——

  static Map<String, dynamic> calendarEventToMap(CalendarEvent event) => {
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'date': event.date.toIso8601String(),
        'type': event.type.name,
        if (event.time != null) 'time': event.time,
        'audience': event.audience,
        'isEthiopianHoliday': event.isEthiopianHoliday,
        'autoAnnounce': event.autoAnnounce,
        'announcementPublished': event.announcementPublished,
        'announcementReminderPublished': event.announcementReminderPublished,
      };

  static CalendarEvent calendarEventFromMap(Map<String, dynamic> map) =>
      CalendarEvent(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        date: DateTime.parse(map['date'] as String),
        type: CalendarEventType.values
            .byName(map['type'] as String? ?? 'other'),
        time: map['time'] as String?,
        audience: map['audience'] as String? ?? 'All',
        isEthiopianHoliday: map['isEthiopianHoliday'] as bool? ?? false,
        autoAnnounce: map['autoAnnounce'] as bool? ?? false,
        announcementPublished: map['announcementPublished'] as bool? ?? false,
        announcementReminderPublished:
            map['announcementReminderPublished'] as bool? ?? false,
      );

  // —— Gallery ——

  static Map<String, dynamic> galleryPostToMap(GalleryPost post) => {
        'id': post.id,
        'className': post.className,
        'type': post.type.name,
        'title': post.title,
        'caption': post.caption,
        'authorName': post.authorName,
        'postedAt': post.postedAt.toIso8601String(),
        if (post.mediaLabel != null) 'mediaLabel': post.mediaLabel,
        if (post.mediaPath != null) 'mediaPath': post.mediaPath,
      };

  static GalleryPost galleryPostFromMap(Map<String, dynamic> map) => GalleryPost(
        id: map['id'] as String,
        className: map['className'] as String? ?? '',
        type: GalleryPostType.values.byName(map['type'] as String? ?? 'photo'),
        title: map['title'] as String? ?? '',
        caption: map['caption'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        postedAt: DateTime.parse(map['postedAt'] as String),
        mediaLabel: map['mediaLabel'] as String?,
        mediaPath: map['mediaPath'] as String?,
      );

  // —— QR scans ——

  static String qrScanDocId(QrScanRecord scan) =>
      '${scan.studentId}_${scan.time.millisecondsSinceEpoch}';

  static Map<String, dynamic> qrScanToMap(QrScanRecord scan) => {
        'studentId': scan.studentId,
        'studentName': scan.studentName,
        'className': scan.className,
        'action': scan.action.name,
        'time': scan.time.toIso8601String(),
        'scannedBy': scan.scannedBy,
      };

  static QrScanRecord qrScanFromMap(Map<String, dynamic> map) => QrScanRecord(
        studentId: map['studentId'] as String,
        studentName: map['studentName'] as String? ?? '',
        className: map['className'] as String? ?? '',
        action: QrScanAction.values.byName(map['action'] as String? ?? 'entry'),
        time: DateTime.parse(map['time'] as String),
        scannedBy: map['scannedBy'] as String? ?? '',
      );

  // —— Attendance ——

  static String attendanceDocId(AttendanceSession session) {
    final day = session.date.toIso8601String().split('T').first;
    return '${session.className}_$day'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static Map<String, dynamic> attendanceSessionToMap(AttendanceSession session) =>
      {
        'className': session.className,
        'date': session.date.toIso8601String(),
        'conductedBy': session.conductedBy,
        'entries': session.entries
            .map(
              (e) => {
                'studentName': e.studentName,
                'status': e.status.name,
              },
            )
            .toList(),
      };

  static AttendanceSession attendanceSessionFromMap(Map<String, dynamic> map) =>
      AttendanceSession(
        className: map['className'] as String? ?? '',
        date: DateTime.parse(map['date'] as String),
        conductedBy: map['conductedBy'] as String? ?? '',
        entries: (map['entries'] as List<dynamic>? ?? const [])
            .map(
              (e) => StudentAttendanceEntry(
                studentName: (e as Map)['studentName'] as String? ?? '',
                status: AttendanceStatus.values
                    .byName(e['status'] as String? ?? 'present'),
              ),
            )
            .toList(),
      );

  // —— Announcements ——

  static Map<String, dynamic> announcementToMap(Announcement a) => {
        'id': a.id,
        'title': a.title,
        'body': a.body,
        'author': a.author,
        'date': a.date.toIso8601String(),
        'audienceKeys': a.audienceKeys,
        'isPinned': a.isPinned,
        'priority': a.priority.name,
        'attachments': a.attachments
            .map(
              (att) => {
                'id': att.id,
                'fileName': att.fileName,
                'filePath': att.filePath,
                if (att.fileSizeBytes != null)
                  'fileSizeBytes': att.fileSizeBytes,
              },
            )
            .toList(),
        if (a.createdByRole != null) 'createdByRole': a.createdByRole,
        if (a.createdByAuthor != null) 'createdByAuthor': a.createdByAuthor,
      };

  static Announcement announcementFromMap(Map<String, dynamic> map) =>
      Announcement(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        author: map['author'] as String? ?? '',
        date: DateTime.parse(map['date'] as String),
        audienceKeys: (map['audienceKeys'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [AnnouncementAudiences.all],
        isPinned: map['isPinned'] as bool? ?? false,
        priority: AnnouncementPriority.values
            .byName(map['priority'] as String? ?? 'normal'),
        attachments: (map['attachments'] as List<dynamic>? ?? const [])
            .map(
              (e) => AnnouncementAttachment(
                id: (e as Map)['id'] as String? ?? '',
                fileName: e['fileName'] as String? ?? '',
                filePath: e['filePath'] as String? ?? '',
                fileSizeBytes: e['fileSizeBytes'] as int?,
              ),
            )
            .toList(),
        createdByRole: map['createdByRole'] as String?,
        createdByAuthor: map['createdByAuthor'] as String?,
      );

  // —— Schools ——

  static Map<String, dynamic> schoolToMap(SchoolRecord school) =>
      school.toJson();

  static SchoolRecord schoolFromMap(Map<String, dynamic> map) =>
      SchoolRecord.fromJson(map);

  // —— Platform audit ——

  static Map<String, dynamic> auditEntryToMap(PlatformAuditEntry entry) =>
      entry.toJson();

  static PlatformAuditEntry auditEntryFromMap(Map<String, dynamic> map) =>
      PlatformAuditEntry.fromJson(map);

  // —— Transport scans & passenger status ——

  static String transportScanDocId(TransportScanRecord scan) =>
      '${scan.driverId}_${scan.studentId}_${scan.time.millisecondsSinceEpoch}';

  static Map<String, dynamic> transportScanToMap(TransportScanRecord scan) => {
        'studentId': scan.studentId,
        'studentName': scan.studentName,
        'driverId': scan.driverId,
        'mode': scan.mode.name,
        'time': scan.time.toIso8601String(),
        'scannedBy': scan.scannedBy,
      };

  static TransportScanRecord transportScanFromMap(Map<String, dynamic> map) =>
      TransportScanRecord(
        studentId: map['studentId'] as String? ?? '',
        studentName: map['studentName'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        mode: TransportScanMode.values.byName(
          map['mode'] as String? ?? 'onboard',
        ),
        time: DateTime.tryParse(map['time'] as String? ?? '') ?? DateTime.now(),
        scannedBy: map['scannedBy'] as String? ?? '',
      );

  static Map<String, dynamic> transportPassengerStatusToMap({
    required String studentId,
    required String driverId,
    required TransportPassengerStatus status,
    required DateTime updatedAt,
    String? updatedBy,
  }) =>
      {
        'studentId': studentId,
        'driverId': driverId,
        'status': status.name,
        'updatedAt': updatedAt.toIso8601String(),
        'updatedBy': ?updatedBy,
      };

  static TransportPassengerStatus transportPassengerStatusFromName(String? raw) {
    return TransportPassengerStatus.values.byName(raw ?? 'waiting');
  }

  // —— Bus live GPS ——

  static Map<String, dynamic> busPositionToMap(BusLivePosition position) => {
        'driverId': position.driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': position.timestamp.toIso8601String(),
        if (position.heading != null) 'heading': position.heading,
        if (position.speedMps != null) 'speedMps': position.speedMps,
      };

  static BusLivePosition busPositionFromMap(Map<String, dynamic> map) =>
      BusLivePosition(
        driverId: (map['driverId'] as String? ?? '').toUpperCase(),
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
        heading: (map['heading'] as num?)?.toDouble(),
        speedMps: (map['speedMps'] as num?)?.toDouble(),
      );

  // —— In-app notifications ——

  static Map<String, dynamic> appNotificationToMap(AppNotification n) => {
        'id': n.id,
        'title': n.title,
        'body': n.body,
        'type': n.type.name,
        'fromRole': n.fromRole,
        'fromName': n.fromName,
        'recipientRole': n.recipientRole,
        'createdAt': n.createdAt.toIso8601String(),
        'showOnMessagesBadge': n.showOnMessagesBadge,
        'isRead': n.isRead,
        if (n.targetStudentId != null) 'targetStudentId': n.targetStudentId,
        if (n.targetClassName != null) 'targetClassName': n.targetClassName,
      };

  static AppNotification appNotificationFromMap(Map<String, dynamic> map) =>
      AppNotification(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        type: NotificationType.values.byName(
          map['type'] as String? ?? 'general',
        ),
        fromRole: map['fromRole'] as String? ?? '',
        fromName: map['fromName'] as String? ?? '',
        recipientRole: map['recipientRole'] as String? ?? '',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        showOnMessagesBadge: map['showOnMessagesBadge'] as bool? ?? true,
        isRead: map['isRead'] as bool? ?? false,
        targetStudentId: map['targetStudentId'] as String?,
        targetClassName: map['targetClassName'] as String?,
      );

  // —— Class timetables ——

  static Map<String, dynamic> classTimetableToMap(ClassTimetable timetable) => {
        'className': timetable.className,
        'homeroomTeacherId': timetable.homeroomTeacherId,
        'homeroomTeacherName': timetable.homeroomTeacherName,
        'updatedAt': timetable.updatedAt.toIso8601String(),
        'days': timetable.days.map(
          (key, day) => MapEntry(
            key,
            {
              'dayKey': day.dayKey,
              'dayStartHour': day.dayStart.hour,
              'dayStartMinute': day.dayStart.minute,
              'slots': day.slots
                  .map(
                    (slot) => {
                      'id': slot.id,
                      'kind': slot.kind.name,
                      if (slot.subject != null) 'subject': slot.subject,
                      'durationMinutes': slot.durationMinutes,
                    },
                  )
                  .toList(),
            },
          ),
        ),
      };

  static ClassTimetable classTimetableFromMap(Map<String, dynamic> map) {
    final rawDays = map['days'] as Map?;
    final days = <String, DayTimetable>{};
    if (rawDays != null) {
      for (final entry in rawDays.entries) {
        final dayMap = Map<String, dynamic>.from(entry.value as Map);
        final slots = (dayMap['slots'] as List? ?? const [])
            .whereType<Map>()
            .map((slotMap) {
              final raw = Map<String, dynamic>.from(slotMap);
              return TimetableSlot(
                id: raw['id'] as String? ?? 'slot',
                kind: TimetableSlotKind.values.byName(
                  raw['kind'] as String? ?? 'lesson',
                ),
                subject: raw['subject'] as String?,
                durationMinutes: raw['durationMinutes'] as int? ?? 40,
              );
            })
            .toList();
        days[entry.key.toString()] = DayTimetable(
          dayKey: dayMap['dayKey'] as String? ?? entry.key.toString(),
          slots: slots,
          dayStart: TimeOfDay(
            hour: dayMap['dayStartHour'] as int? ?? 8,
            minute: dayMap['dayStartMinute'] as int? ?? 0,
          ),
        );
      }
    }

    return ClassTimetable(
      className: map['className'] as String? ?? '',
      homeroomTeacherId: map['homeroomTeacherId'] as String? ?? '',
      homeroomTeacherName: map['homeroomTeacherName'] as String? ?? '',
      days: days,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
