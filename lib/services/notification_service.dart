import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/platform/web_browser_notification.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/pending_notification_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
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
      isRead: true,
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
      isRead: true,
    ),
  ];

  final Set<String> _persistedReadIds = {};
  String _hydratedForUsername = '';

  static String _readIdsKey(String username) =>
      'notif_read_ids_v1_${username.trim().toLowerCase()}';

  static String _fingerprint(AppNotification item) =>
      'fp:${item.type.name}|${item.title}|${item.body}|${item.recipientRole}|'
      '${item.recipientStaffRole ?? ''}|'
      '${item.recipientStaffId ?? ''}|${item.recipientUsername ?? ''}';

  Future<void> hydratePersistedReads() async {
    final username =
        AuthService.currentUser?.username.trim().toLowerCase() ?? '';
    if (username.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_readIdsKey(username)) ?? const [];
      if (_hydratedForUsername != username) {
        _persistedReadIds.clear();
        _hydratedForUsername = username;
      }
      _persistedReadIds.addAll(stored);
      _applyPersistedReadsToItems();
    } catch (_) {}
  }

  Future<void> _saveReadIds() async {
    final username =
        AuthService.currentUser?.username.trim().toLowerCase() ?? '';
    if (username.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _readIdsKey(username),
        _persistedReadIds.toList()..sort(),
      );
    } catch (_) {}
  }

  void _rememberRead(AppNotification item) {
    item.isRead = true;
    _persistedReadIds.add(item.id);
    _persistedReadIds.add(_fingerprint(item));
  }

  bool _wasRead(AppNotification item) =>
      item.isRead ||
      _persistedReadIds.contains(item.id) ||
      _persistedReadIds.contains(_fingerprint(item));

  void _applyPersistedReadsToItems() {
    var changed = false;
    for (final item in _items) {
      if (_wasRead(item) && !item.isRead) {
        item.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void _persistReadsSoon() => unawaited(_saveReadIds());

  String get _currentRole =>
      AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;

  List<AppNotification> notificationsForCurrentUser() {
    final role = _currentRole;
    return _items.where((item) => _matchesCurrentUser(item, role)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  bool _matchesCurrentUser(AppNotification item, String role) {
    final staffTarget = item.recipientStaffRole?.trim() ?? '';
    if (staffTarget.isNotEmpty) {
      final held = AuthService.currentUser?.staffRoles ?? const <String>[];
      if (!StaffRoles.holds(held, staffTarget)) return false;
    } else if (item.recipientRole != role) {
      return false;
    }
    if (!_matchesPersonTarget(
      recipientStaffId: item.recipientStaffId,
      recipientUsername: item.recipientUsername,
      recipientUsernames: item.recipientUsernames,
    )) {
      return false;
    }
    if (role == AuthService.roleParent) {
      if (item.type == NotificationType.attendance &&
          !NotificationPreferenceService.instance.isEnabled(
            AuthService.roleParent,
            NotificationPreferenceKey.attendance,
          )) {
        return false;
      }
      return _matchesLinkedStudentScope(
        item,
        AuthService.activeLinkedStudentIds()
            .map((id) => id.trim().toUpperCase())
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
    }
    if (role == AuthService.roleStudent) {
      final linkedStudentId = AuthService.currentUser?.linkedStudentId
          ?.trim()
          .toUpperCase();
      if (linkedStudentId == null || linkedStudentId.isEmpty) return false;
      return _matchesLinkedStudentScope(item, {linkedStudentId});
    }
    if (item.type == NotificationType.message &&
        !_hasDirectPersonTarget(item) &&
        staffTarget.isEmpty) {
      return false;
    }
    return true;
  }

  bool _hasDirectPersonTarget(AppNotification item) {
    final staffId = item.recipientStaffId?.trim();
    if (staffId != null && staffId.isNotEmpty) return true;
    final username = item.recipientUsername?.trim();
    if (username != null && username.isNotEmpty) return true;
    return item.recipientUsernames.any((u) => u.trim().isNotEmpty);
  }

  /// Direct staff/username notices stay with that person; role-wide
  /// broadcasts (no person target) still reach the whole role.
  bool _matchesPersonTarget({
    String? recipientStaffId,
    String? recipientUsername,
    List<String>? recipientUsernames,
  }) {
    final user = AuthService.currentUser;
    if (user == null) return false;

    final explicitUser = recipientUsername?.trim().toLowerCase();
    if (explicitUser != null && explicitUser.isNotEmpty) {
      if (explicitUser != user.username.trim().toLowerCase()) return false;
    }

    if (recipientUsernames != null && recipientUsernames.isNotEmpty) {
      final allowed = recipientUsernames
          .map((u) => u.trim().toLowerCase())
          .where((u) => u.isNotEmpty)
          .toSet();
      if (!allowed.contains(user.username.trim().toLowerCase())) return false;
    }

    final staffId = recipientStaffId?.trim();
    if (staffId != null && staffId.isNotEmpty) {
      final viewerStaffId = StaffMemberOption.viewerCompositeStaffId(
        user.roleKey,
      );
      if (viewerStaffId == null ||
          !StaffMemberOption.idsEqual(viewerStaffId, staffId)) {
        return false;
      }
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

  int unreadCountForTypes(List<NotificationType> types, {String? roleKey}) {
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
    String? recipientStaffRole,
    String? recipientUsername,
    List<String>? recipientUsernames,
  }) {
    final usernames = [
      if (recipientUsername != null && recipientUsername.trim().isNotEmpty)
        recipientUsername.trim(),
      ...?recipientUsernames?.where((u) => u.trim().isNotEmpty),
    ];
    final hasPersonTarget =
        (recipientStaffId != null && recipientStaffId.trim().isNotEmpty) ||
        usernames.isNotEmpty;
    if (hasPersonTarget &&
        _matchesPersonTarget(
          recipientStaffId: recipientStaffId,
          recipientUsername: recipientUsername,
          recipientUsernames: usernames,
        )) {
      return;
    }
    final staffTarget = recipientStaffRole?.trim() ?? '';
    if (staffTarget.isEmpty &&
        !hasPersonTarget &&
        recipientRole == fromRole &&
        AuthService.currentUser?.roleKey == fromRole) {
      return;
    }
    if (type == NotificationType.attendance &&
        !NotificationPreferenceService.instance.isEnabled(
          recipientRole,
          NotificationPreferenceKey.attendance,
        )) {
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
        recipientStaffId: recipientStaffId?.trim().isEmpty == true
            ? null
            : recipientStaffId?.trim(),
        recipientStaffRole: staffTarget.isEmpty ? null : staffTarget,
        recipientUsername: recipientUsername?.trim().isEmpty == true
            ? null
            : recipientUsername?.trim(),
        recipientUsernames: usernames,
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
      recipientStaffRole: staffTarget.isEmpty ? null : staffTarget,
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
          recipientStaffRole: staffTarget.isEmpty ? null : staffTarget,
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
        recipientStaffRole: staffTarget.isEmpty ? null : staffTarget,
        recipientUsername: recipientUsername,
        recipientUsernames: recipientUsernames,
      ),
    );
  }

  /// Call after login / session restore to show queued phone notifications.
  Future<void> onSessionStarted() async {
    await hydratePersistedReads();
    final delivered = await PendingNotificationStore.instance
        .deliverForCurrentUser();
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

      final created = AppNotification(
        id: 'n-${_nextId++}',
        title: title,
        body: body,
        type: type,
        fromRole: item['fromRole'] as String? ?? '',
        fromName: item['fromName'] as String? ?? '',
        recipientRole: recipientRole,
        createdAt:
            DateTime.tryParse(item['createdAt'] as String? ?? '') ??
            DateTime.now(),
        targetStudentId: item['targetStudentId'] as String?,
        targetClassName: item['targetClassName'] as String?,
        recipientStaffId: item['recipientStaffId'] as String?,
        recipientStaffRole: item['recipientStaffRole'] as String?,
        recipientUsername: item['recipientUsername'] as String?,
        recipientUsernames:
            (item['recipientUsernames'] as List?)
                ?.map((u) => u.toString())
                .where((u) => u.trim().isNotEmpty)
                .toList() ??
            const [],
      );
      if (_wasRead(created)) {
        created.isRead = true;
      }
      _items.insert(0, created);
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
      if (_wasRead(cloud)) {
        cloud.isRead = true;
      }
      final index = _items.indexWhere((n) => n.id == cloud.id);
      if (index >= 0) {
        final existing = _items[index];
        final keepRead = existing.isRead || cloud.isRead;
        if (existing.createdAt.isBefore(cloud.createdAt)) {
          _items[index] = cloud;
          changed = true;
        }
        if (keepRead && !_items[index].isRead) {
          _items[index].isRead = true;
          changed = true;
        }
      } else {
        _items.add(cloud);
        changed = true;
        if (!cloud.isRead &&
            (newest == null || cloud.createdAt.isAfter(newest.createdAt))) {
          newest = cloud;
        }
      }
    }
    if (changed) {
      _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      if (kIsWeb && newest != null && !newest.isRead && !_wasRead(newest)) {
        unawaited(
          showWebBrowserNotification(title: newest.title, body: newest.body),
        );
      }
    }
  }

  void markRead(String id) {
    try {
      final item = _items.firstWhere((n) => n.id == id);
      if (!item.isRead) {
        _rememberRead(item);
        notifyListeners();
        _persistReadsSoon();
      }
    } catch (_) {}
  }

  void markTypesRead(List<NotificationType> types, {String? roleKey}) {
    final role = roleKey ?? _currentRole;
    final typeSet = types.toSet();
    var changed = false;
    for (final item in _items) {
      if (_matchesCurrentUser(item, role) &&
          typeSet.contains(item.type) &&
          !item.isRead) {
        _rememberRead(item);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persistReadsSoon();
    }
  }

  void markAllRead({String? roleKey}) {
    final role = roleKey ?? _currentRole;
    var changed = false;
    for (final item in _items) {
      if (_matchesCurrentUser(item, role) && !item.isRead) {
        _rememberRead(item);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persistReadsSoon();
    }
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
        _rememberRead(item);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persistReadsSoon();
    }
  }

  void refreshBadges() => notifyListeners();

  void clearForLogout() {
    _items.clear();
    _nextId = 1;
    _persistedReadIds.clear();
    _hydratedForUsername = '';
    notifyListeners();
  }

  @visibleForTesting
  List<AppNotification> itemsForTests() => List.unmodifiable(_items);

  @visibleForTesting
  void resetForTests() {
    _persistedReadIds.clear();
    _hydratedForUsername = '';
    _nextId = 1;
    if (_items.every((item) => item.id != 'seed-1')) {
      _items.add(
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
          isRead: true,
        ),
      );
    }
    if (_items.every((item) => item.id != 'seed-2')) {
      _items.add(
        AppNotification(
          id: 'seed-2',
          title: 'New message',
          body: 'Mr. Bekele asked about today\'s homework.',
          type: NotificationType.message,
          fromRole: AuthService.roleParent,
          fromName: 'Mr. Bekele',
          recipientRole: AuthService.roleTeacher,
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          isRead: true,
        ),
      );
    }
    for (final item in _items) {
      if (item.id == 'seed-1' || item.id == 'seed-2') item.isRead = true;
    }
  }
}
