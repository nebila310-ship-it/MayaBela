import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';

/// Device tray / lock-screen alerts via local notifications.
/// When the recipient is logged in, shows immediately; otherwise
/// [PendingNotificationStore] delivers on next login.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  static const _channelId = 'maya_school_alerts';
  static const _channelName = 'Maya School Alerts';
  static const _platformChannelId = 'maya_platform_owner';
  static const _platformChannelName = 'Maya Platform Owner';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _idCounter = 0;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Homework, messages, transport and school updates',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _platformChannelId,
        _platformChannelName,
        description: 'Subscription expiry and platform owner alerts',
        importance: Importance.max,
      ),
    );

    await ensurePermission();
    _initialized = true;
  }

  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted == true) return true;
      final enabled = await android.areNotificationsEnabled();
      return enabled ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  bool matchesCurrentRecipient({
    required NotificationType type,
    required String recipientRole,
    String? targetStudentId,
    String? targetClassName,
    String? recipientStaffId,
    List<String>? recipientUsernames,
    String? recipientUsername,
  }) {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != recipientRole) return false;

    final prefs = NotificationPreferenceService.instance;
    if (!prefs.isEnabled(recipientRole, NotificationPreferenceKey.master)) {
      return false;
    }
    final category = preferenceKeyForType(type);
    if (!prefs.isEnabled(recipientRole, category)) return false;

    if (recipientRole == AuthService.roleParent) {
      EnrollmentService.instance.ensureSeeded();
      final linked = AuthService.activeLinkedStudentIds()
          .map((id) => id.trim().toUpperCase())
          .toSet();

      final target = targetStudentId?.trim().toUpperCase();
      if (target != null && target.isNotEmpty && !linked.contains(target)) {
        return false;
      }

      final className = targetClassName?.trim();
      if (className != null && className.isNotEmpty) {
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

    if (recipientRole == AuthService.roleStudent) {
      final linkedStudentId =
          user.linkedStudentId?.trim().toUpperCase();
      if (linkedStudentId == null || linkedStudentId.isEmpty) return false;

      final target = targetStudentId?.trim().toUpperCase();
      if (target != null &&
          target.isNotEmpty &&
          target != linkedStudentId) {
        return false;
      }

      final className = targetClassName?.trim();
      if (className != null && className.isNotEmpty) {
        final student = StudentRegistryService.instance.lookupById(linkedStudentId);
        if (student == null ||
            !StudentRegistryService.classNamesMatch(
              student.className,
              className,
            )) {
          return false;
        }
      }
    }

    if (recipientUsername != null &&
        recipientUsername.trim().toLowerCase() != user.username.toLowerCase()) {
      return false;
    }

    if (recipientUsernames != null && recipientUsernames.isNotEmpty) {
      final allowed = recipientUsernames
          .map((u) => u.trim().toLowerCase())
          .where((u) => u.isNotEmpty)
          .toSet();
      if (!allowed.contains(user.username.toLowerCase())) return false;
    }

    if (recipientStaffId != null && recipientStaffId.trim().isNotEmpty) {
      final viewerStaffId = StaffMemberOption.viewerStaffId(user.roleKey);
      if (viewerStaffId == null ||
          viewerStaffId.trim() != recipientStaffId.trim()) {
        return false;
      }
    }

    return true;
  }

  Future<void> showForEvent({
    required NotificationType type,
    required String recipientRole,
    required String title,
    required String body,
    String? targetStudentId,
    String? targetClassName,
    String? recipientStaffId,
    List<String>? recipientUsernames,
    String? recipientUsername,
  }) async {
    if (kIsWeb || !_initialized) return;

    if (!matchesCurrentRecipient(
      type: type,
      recipientRole: recipientRole,
      targetStudentId: targetStudentId,
      targetClassName: targetClassName,
      recipientStaffId: recipientStaffId,
      recipientUsernames: recipientUsernames,
      recipientUsername: recipientUsername,
    )) {
      return;
    }

    await showTrayNotification(title: title, body: body);
  }

  Future<void> showTrayNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    await ensurePermission();
    final playSound = UserPreferencesService.instance.notificationSounds;

    await _plugin.show(
      ++_idCounter,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Homework, messages, transport and school updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: playSound,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
        ),
      ),
    );
  }

  /// Platform owner alerts — not tied to a school user role.
  Future<void> showPlatformOwnerAlert({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;

    await _plugin.show(
      ++_idCounter,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _platformChannelId,
          _platformChannelName,
          channelDescription: 'Subscription expiry and platform owner alerts',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
