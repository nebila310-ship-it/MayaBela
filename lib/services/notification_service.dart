import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/platform/web_browser_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/pending_notification_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/student_registry_service.dart';
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final instance = NotificationService._();

  int _nextId = 1;
  final List<AppNotification> _items = [
    AppNotification(
      id: 'seed-1',
      title: 'Homework posted',
      body: 'Miss Belen added Mathematics homework for Grade 4A.',
      type: NotificationType.homework,
      fromRole: AuthService.roleTeacher,
      fromName: 'Miss Belen',
      recipientRole: AuthService.roleParent,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      targetClassName: 'Grade 4A',
    ),
    AppNotification(
      id: 'seed-2',
      title: 'New message',
      body: 'Mr. Bekele asked about today\'s homework.',
      type: NotificationType.message,
      fromRole: AuthService.roleParent,
      fromName: 'Mr. Bekele',
      recipientRole: AuthService.roleTeacher,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
  ];

  String get _currentRole =>
      AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;

  List<AppNotification> notificationsForCurrentUser() {
    final role = _currentRole;
    return _items.where((item) => _matchesCurrentUser(item, role)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool _matchesCurrentUser(AppNotification item, String role) {
    if (item.recipientRole != role) return false;
    if (role == AuthService.roleParent) {
      return _matchesLinkedStudentScope(
        item,
        AuthService.activeLinkedStudentIds()
            .map((id) => id.trim().toUpperCase())
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
    }
    if (role == AuthService.roleStudent) {
      final linkedStudentId =
          AuthService.currentUser?.linkedStudentId?.trim().toUpperCase();
      if (linkedStudentId == null || linkedStudentId.isEmpty) return false;
      return _matchesLinkedStudentScope(item, {linkedStudentId});
    }
    return true;
  }

  bool _matchesLinkedStudentScope(
    AppNotification item,
    Set<String> linkedStudentIds,
  ) {
    final target = item.targetStudentId?.trim().toUpperCase();
    if (target != null && target.isNotEmpty) {
      if (!linkedStudentIds.contains(target)) return false;
    }

    final className = item.targetClassName?.trim();
    if (className != null && className.isNotEmpty) {
      var inClass = false;
      for (final studentId in linkedStudentIds) {
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

    return true;
  }

  int unreadCount({String? roleKey}) {
    final role = roleKey ?? _currentRole;
    return _items
        .where((item) => _matchesCurrentUser(item, role) && !item.isRead)
        .length;
  }

  int unreadCountForTypes(
    List<NotificationType> types, {
    String? roleKey,
  }) {
    final role = roleKey ?? _currentRole;
    final typeSet = types.toSet();
    return _items
        .where(
          (item) =>
              _matchesCurrentUser(item, role) &&
              !item.isRead &&
              typeSet.contains(item.type),
        )
        .length;
  }

  int unreadCountForTypesSince(
    List<NotificationType> types, {
    String? roleKey,
    DateTime? since,
  }) {
    final role = roleKey ?? _currentRole;
    final typeSet = types.toSet();
    return _items
        .where(
          (item) =>
              _matchesCurrentUser(item, role) &&
              !item.isRead &&
              typeSet.contains(item.type) &&
              (since == null || item.createdAt.isAfter(since)),
        )
        .length;
  }

  int messagesBadgeCount({String? roleKey}) {
    final role = roleKey ?? _currentRole;
    return _items
        .where(
          (item) =>
              _matchesCurrentUser(item, role) &&
              !item.isRead &&
              item.showOnMessagesBadge,
        )
        .length;
  }

  void push({
    required String title,
    required String body,
    required NotificationType type,
    required String fromRole,
    required String fromName,
    required String recipientRole,
    bool showOnMessagesBadge = true,
    String? targetStudentId,
    String? targetClassName,
    String? recipientStaffId,
    String? recipientUsername,
    List<String>? recipientUsernames,
  }) {
    if (recipientRole == fromRole &&
        AuthService.currentUser?.roleKey == fromRole) {
      return;
    }

    _items.insert(
      0,
      AppNotification(
        id: 'n-${_nextId++}',
        title: title,
        body: body,
        type: type,
        fromRole: fromRole,
        fromName: fromName,
        recipientRole: recipientRole,
        createdAt: DateTime.now(),
        showOnMessagesBadge: showOnMessagesBadge,
        targetStudentId: targetStudentId,
        targetClassName: targetClassName,
      ),
    );
    final created = _items.first;
    notifyListeners();
    unawaited(CloudAppStore.instance.pushAppNotification(created));

    final deliverNow = PushNotificationService.instance.matchesCurrentRecipient(
      type: type,
      recipientRole: recipientRole,
      targetStudentId: targetStudentId,
      targetClassName: targetClassName,
      recipientStaffId: recipientStaffId,
      recipientUsername: recipientUsername,
      recipientUsernames: recipientUsernames,
    );

    if (!deliverNow) {
      unawaited(
        PendingNotificationStore.instance.enqueue(
          title: title,
          body: body,
          type: type,
          recipientRole: recipientRole,
          fromRole: fromRole,
          fromName: fromName,
          targetStudentId: targetStudentId,
          targetClassName: targetClassName,
          recipientStaffId: recipientStaffId,
          recipientUsername: recipientUsername,
          recipientUsernames: recipientUsernames,
        ),
      );
    }

    unawaited(
      PushNotificationService.instance.showForEvent(
        type: type,
        recipientRole: recipientRole,
        title: title,
        body: body,
        targetStudentId: targetStudentId,
        targetClassName: targetClassName,
        recipientStaffId: recipientStaffId,
        recipientUsername: recipientUsername,
        recipientUsernames: recipientUsernames,
      ),
    );
  }

  /// Call after login / session restore to show queued phone notifications.
  Future<void> onSessionStarted() async {
    final delivered = await PendingNotificationStore.instance.deliverForCurrentUser();
    if (delivered.isEmpty) return;

    for (final item in delivered) {
      final typeName = item['type'] as String? ?? NotificationType.general.name;
      final type = NotificationType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => NotificationType.general,
      );
      final title = item['title'] as String? ?? 'School update';
      final body = item['body'] as String? ?? '';
      final recipientRole = item['recipientRole'] as String? ?? '';
      if (recipientRole.isEmpty) continue;

      final exists = _items.any(
        (n) =>
            n.title == title &&
            n.body == body &&
            n.recipientRole == recipientRole &&
            DateTime.now().difference(n.createdAt).inMinutes < 2,
      );
      if (exists) continue;

      _items.insert(
        0,
        AppNotification(
          id: 'n-${_nextId++}',
          title: title,
          body: body,
          type: type,
          fromRole: item['fromRole'] as String? ?? '',
          fromName: item['fromName'] as String? ?? '',
          recipientRole: recipientRole,
          createdAt: DateTime.tryParse(item['createdAt'] as String? ?? '') ??
              DateTime.now(),
          targetStudentId: item['targetStudentId'] as String?,
          targetClassName: item['targetClassName'] as String?,
        ),
      );
    }
    notifyListeners();
  }

  /// Merge notifications pulled from Firestore (cloud wins on same id).
  void applyCloudNotifications(List<AppNotification> cloudItems) {
    var changed = false;
    AppNotification? newest;
    final role = _currentRole;
    for (final cloud in cloudItems) {
      if (!_matchesCurrentUser(cloud, role)) continue;
      final index = _items.indexWhere((n) => n.id == cloud.id);
      if (index >= 0) {
        if (_items[index].createdAt.isBefore(cloud.createdAt)) {
          _items[index] = cloud;
          changed = true;
        }
      } else {
        _items.add(cloud);
        changed = true;
        if (newest == null || cloud.createdAt.isAfter(newest.createdAt)) {
          newest = cloud;
        }
      }
    }
    if (changed) {
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      if (kIsWeb && newest != null && !newest.isRead) {
        unawaited(
          showWebBrowserNotification(
            title: newest.title,
            body: newest.body,
          ),
        );
      }
    }
  }

  void markRead(String id) {
    try {
      final item = _items.firstWhere((n) => n.id == id);
      if (!item.isRead) {
        item.isRead = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void markTypesRead(
    List<NotificationType> types, {
    String? roleKey,
  }) {
    final role = roleKey ?? _currentRole;
    final typeSet = types.toSet();
    var changed = false;
    for (final item in _items) {
      if (_matchesCurrentUser(item, role) &&
          typeSet.contains(item.type) &&
          !item.isRead) {
        item.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markAllRead({String? roleKey}) {
    final role = roleKey ?? _currentRole;
    var changed = false;
    for (final item in _items) {
      if (_matchesCurrentUser(item, role) && !item.isRead) {
        item.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void markTypeRead(NotificationType type, {String? roleKey}) {
    markTypesRead([type], roleKey: roleKey);
  }

  void markMessagesBadgeRead({String? roleKey}) {
    final role = roleKey ?? _currentRole;
    var changed = false;
    for (final item in _items) {
      if (_matchesCurrentUser(item, role) &&
          item.showOnMessagesBadge &&
          !item.isRead) {
        item.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void refreshBadges() => notifyListeners();

  void clearForLogout() {
    _items.clear();
    _nextId = 1;
    notifyListeners();
  }
}
