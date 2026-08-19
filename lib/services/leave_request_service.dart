import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/leave_request_persistence_service.dart';

/// EDUABA — parent leave requests routed to the homeroom teacher.
///
/// Parents submit for a linked child; homeroom teacher (or Student Affairs /
/// admin) approves or rejects. Synced via the `leave_requests` collection.
class LeaveRequestService extends ChangeNotifier {
  LeaveRequestService._();
  static final instance = LeaveRequestService._();

  final List<LeaveRequest> _requests = [];
  bool _loaded = false;

  List<LeaveRequest> get allRequests => List.unmodifiable(_requests);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await LeaveRequestPersistenceService.instance.loadIntoService();
  }

  List<LeaveRequest> forSchool(String? schoolId) {
    final sid = schoolId?.trim().toUpperCase();
    if (sid == null || sid.isEmpty) return allRequests;
    return _requests.where((r) => r.schoolId == sid).toList();
  }

  List<LeaveRequest> forParent(String parentUsername) {
    final uname = parentUsername.trim().toLowerCase();
    return _requests
        .where((r) => r.parentUsername.trim().toLowerCase() == uname)
        .toList();
  }

  List<LeaveRequest> forClasses(Iterable<String> classNames) {
    final names = classNames.map((c) => c.trim()).toSet();
    return _requests.where((r) => names.contains(r.className.trim())).toList();
  }

  Future<LeaveRequest> submit({
    required String studentId,
    required String studentName,
    required String className,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final user = AuthService.currentUser;
    final now = DateTime.now();
    final request = LeaveRequest(
      id: 'lr-${now.millisecondsSinceEpoch}',
      schoolId: (AuthService.activeSchoolId ?? user?.schoolId ?? '')
          .trim()
          .toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: studentName.trim(),
      className: className.trim(),
      parentUsername: user?.username ?? '',
      parentName: user?.fullName ?? user?.username ?? 'Parent',
      startDate: startDate,
      endDate: endDate,
      reason: reason.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _requests.insert(0, request);
    notifyListeners();
    await LeaveRequestPersistenceService.instance.saveFromService();

    NotificationService.instance.push(
      title: 'Leave request — ${request.studentName}',
      body:
          '${request.parentName} requested leave for ${request.studentName} '
          '(${_dateLabel(startDate)} → ${_dateLabel(endDate)}): $reason',
      type: NotificationType.general,
      fromRole: AuthService.roleParent,
      fromName: request.parentName,
      recipientRole: AuthService.roleTeacher,
      targetStudentId: request.studentId,
      targetClassName: request.className,
    );
    return request;
  }

  Future<LeaveRequest?> review(
    String id, {
    required bool approve,
    String note = '',
  }) async {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index < 0) return null;
    final reviewer = AuthService.currentUser;
    final updated = _requests[index].copyWith(
      status: approve ? LeaveRequestStatus.approved : LeaveRequestStatus.rejected,
      reviewedByName: reviewer?.fullName ?? reviewer?.username ?? 'Staff',
      reviewNote: note.trim(),
      reviewedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _requests[index] = updated;
    notifyListeners();
    await LeaveRequestPersistenceService.instance.saveFromService();

    NotificationService.instance.push(
      title: 'Leave ${approve ? 'approved' : 'rejected'} — ${updated.studentName}',
      body:
          'Your leave request for ${updated.studentName} was '
          '${approve ? 'approved' : 'rejected'} by ${updated.reviewedByName}.'
          '${note.trim().isNotEmpty ? ' Note: ${note.trim()}' : ''}',
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: updated.reviewedByName,
      recipientRole: AuthService.roleParent,
      targetStudentId: updated.studentId,
      recipientUsername: updated.parentUsername,
    );
    return updated;
  }

  void applyPersistedData(List<LeaveRequest> items, {bool merge = false}) {
    if (!merge) {
      _requests
        ..clear()
        ..addAll(items);
    } else {
      final byId = {for (final r in _requests) r.id: r};
      for (final incoming in items) {
        final existing = byId[incoming.id];
        if (existing == null ||
            incoming.updatedAt.isAfter(existing.updatedAt)) {
          byId[incoming.id] = incoming;
        }
      }
      _requests
        ..clear()
        ..addAll(byId.values);
    }
    _requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _requests.map((r) => r.toMap()).toList();

  static String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
