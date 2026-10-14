import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/student_id_utils.dart';

/// Notices about one child. Without a student id they must not fan out.
bool notificationNamesOneStudent(NotificationType type) {
  switch (type) {
    case NotificationType.grade:
    case NotificationType.fee:
    case NotificationType.bus:
    case NotificationType.qrScan:
    case NotificationType.dailyActivity:
    case NotificationType.dailyActivitySeen:
    case NotificationType.general:
    case NotificationType.materialPurchase:
      return true;
    default:
      return false;
  }
}

/// School-wide family notices (no class, no student) such as a holiday.
bool notificationIsSchoolWideForFamily(NotificationType type) {
  return type == NotificationType.announcement ||
      type == NotificationType.calendar;
}

bool notificationSchoolMatchesViewer(String? noticeSchoolId) {
  final notice = noticeSchoolId?.trim().toUpperCase() ?? '';
  if (notice.isEmpty) return true;
  final viewer = (AuthService.activeSchoolId ?? '').trim().toUpperCase();
  if (viewer.isEmpty) return true;
  return notice == viewer;
}

bool linkedIdsIncludeStudent(Set<String> linkedStudentIds, String target) {
  for (final id in linkedStudentIds) {
    if (studentIdsMatch(id, target)) return true;
  }
  return false;
}

bool linkedChildIsInClass(Set<String> linkedStudentIds, String className) {
  for (final studentId in linkedStudentIds) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student != null &&
        StudentRegistryService.classNamesMatch(student.className, className)) {
      return true;
    }
  }
  return false;
}

/// Parent and student inboxes. A named child stays with that family.
/// Class homework and announcements stay with that class. A notice that
/// names one child but has no student id is hidden.
bool familyNotificationReaches({
  required AppNotification item,
  required Set<String> linkedStudentIds,
  required bool addressedToThisPerson,
}) {
  final target = item.targetStudentId?.trim() ?? '';
  if (target.isNotEmpty) {
    return linkedIdsIncludeStudent(linkedStudentIds, target);
  }
  if (addressedToThisPerson) return true;
  if (notificationNamesOneStudent(item.type)) return false;

  final className = item.targetClassName?.trim() ?? '';
  if (className.isEmpty) {
    return notificationIsSchoolWideForFamily(item.type);
  }
  return linkedChildIsInClass(linkedStudentIds, className);
}

/// Class notices stay with teachers of that class. A direct staff or
/// username target is already that person, so the class list does not
/// hide it.
bool teacherClassNotificationReaches({
  required String? targetClassName,
  required List<String> assignedClasses,
  required bool addressedToThisPerson,
}) {
  if (addressedToThisPerson) return true;
  final className = targetClassName?.trim() ?? '';
  if (className.isEmpty) return true;
  final names = assignedClasses
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
  if (names.isEmpty) return true;
  return names.any(
    (name) => StudentRegistryService.classNamesMatch(name, className),
  );
}
