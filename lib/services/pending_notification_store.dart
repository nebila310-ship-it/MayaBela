import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

/// Queues tray notifications for users who are not logged in when an event fires.
class PendingNotificationStore {
  PendingNotificationStore._();
  static final instance = PendingNotificationStore._();

  static const _storageKey = 'pending_tray_notifications_v1';

  Future<void> enqueue({
    required String title,
    required String body,
    required NotificationType type,
    required String recipientRole,
    required String fromRole,
    required String fromName,
    String? recipientUsername,
    String? recipientStaffId,
    String? targetStudentId,
    String? targetClassName,
    List<String>? recipientUsernames,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _readList(prefs);
    existing.add({
      'title': title,
      'body': body,
      'type': type.name,
      'recipientRole': recipientRole,
      'fromRole': fromRole,
      'fromName': fromName,
      'recipientUsername': ?recipientUsername,
      'recipientStaffId': ?recipientStaffId,
      'targetStudentId': ?targetStudentId,
      'targetClassName': ?targetClassName,
      if (recipientUsernames != null && recipientUsernames.isNotEmpty)
        'recipientUsernames': recipientUsernames,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_storageKey, jsonEncode(existing));
  }

  Future<List<Map<String, dynamic>>> deliverForCurrentUser() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    await PushNotificationService.instance.ensurePermission();

    final prefs = await SharedPreferences.getInstance();
    final all = _readList(prefs);
    if (all.isEmpty) return [];

    final kept = <Map<String, dynamic>>[];
    final delivered = <Map<String, dynamic>>[];

    for (final item in all) {
      if (_matchesCurrentUser(item, user)) {
        delivered.add(item);
      } else {
        kept.add(item);
      }
    }

    if (delivered.isEmpty) return [];

    await prefs.setString(_storageKey, jsonEncode(kept));

    final prefService = NotificationPreferenceService.instance;
    for (final item in delivered) {
      final type = _typeFromName(item['type'] as String?);
      if (!prefService.isEnabled(user.roleKey, NotificationPreferenceKey.master)) {
        continue;
      }
      final category = preferenceKeyForType(type);
      if (!prefService.isEnabled(user.roleKey, category)) continue;

      await PushNotificationService.instance.showTrayNotification(
        title: item['title'] as String? ?? 'School update',
        body: item['body'] as String? ?? '',
      );
    }

    return delivered;
  }

  bool _matchesCurrentUser(Map<String, dynamic> item, RegisteredUser user) {
    if (item['recipientRole'] != user.roleKey) return false;

    final explicitUser = (item['recipientUsername'] as String?)?.trim().toLowerCase();
    if (explicitUser != null &&
        explicitUser.isNotEmpty &&
        explicitUser != user.username.toLowerCase()) {
      return false;
    }

    final usernames = item['recipientUsernames'];
    if (usernames is List && usernames.isNotEmpty) {
      final allowed = usernames
          .map((u) => u.toString().trim().toLowerCase())
          .where((u) => u.isNotEmpty)
          .toSet();
      if (!allowed.contains(user.username.toLowerCase())) return false;
    }

    final staffId = item['recipientStaffId'] as String?;
    if (staffId != null && staffId.trim().isNotEmpty) {
      final viewerStaffId = StaffMemberOption.viewerStaffId(user.roleKey);
      if (viewerStaffId == null ||
          viewerStaffId.trim() != staffId.trim()) {
        return false;
      }
    }

    if (user.roleKey == AuthService.roleParent) {
      EnrollmentService.instance.ensureSeeded();
      final linked = EnrollmentService.instance
          .approvedStudentIdsForParent(user.username)
          .map((id) => id.toUpperCase())
          .toSet();
      linked.addAll(
        user.linkedStudentIds.map((id) => id.toUpperCase()),
      );

      final targetStudent = (item['targetStudentId'] as String?)?.trim().toUpperCase();
      if (targetStudent != null &&
          targetStudent.isNotEmpty &&
          !linked.contains(targetStudent)) {
        return false;
      }

      final className = item['targetClassName'] as String?;
      if (className != null && className.trim().isNotEmpty) {
        var inClass = false;
        for (final studentId in linked) {
          final student = StudentRegistryService.instance.lookupById(studentId);
          if (student != null &&
              StudentRegistryService.classNamesMatch(
                student.className,
                className,
              )) {
            inClass = true;
            break;
          }
        }
        if (!inClass) return false;
      }
    }

    return true;
  }

  NotificationType _typeFromName(String? name) {
    for (final type in NotificationType.values) {
      if (type.name == name) return type;
    }
    return NotificationType.general;
  }

  List<Map<String, dynamic>> _readList(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
