import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/push_notification_service.dart';

/// Registers device FCM tokens (stored in Supabase `fcm_tokens`) and handles
/// remote push while the app is foregrounded. Firebase is used ONLY as the
/// push transport; delivery is triggered by the Supabase `send-push` edge
/// function whenever an `app_notifications` row is inserted.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  String? _token;
  bool _fcmReady = false;
  final _crud = DocumentStore();

  String? get token => _token;

  Future<void> init() async {
    if (kIsWeb) return;

    try {
      // Reads android/app/google-services.json natively; no Dart options file.
      await Firebase.initializeApp();
      _fcmReady = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmService: Firebase init failed — $e');
      }
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      _token = await messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmService: getToken failed — $e');
      }
    }
    await _saveTokenForCurrentUser();

    messaging.onTokenRefresh.listen((token) async {
      _token = token;
      await _saveTokenForCurrentUser();
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromTray);
  }

  Future<void> registerForCurrentUser() async {
    if (!_fcmReady || kIsWeb) return;
    try {
      _token ??= await FirebaseMessaging.instance.getToken();
    } catch (_) {}
    await _saveTokenForCurrentUser();
  }

  Future<void> clearTokenForCurrentUser() async {
    final user = AuthService.currentUser;
    if (user == null || !SupabaseBootstrap.isInitialized) return;
    try {
      await _crud.deleteDoc(
        collection: AppCollections.fcmTokens,
        docId: user.username,
      );
    } catch (_) {}
  }

  Future<void> _saveTokenForCurrentUser() async {
    final user = AuthService.currentUser;
    final token = _token;
    if (user == null || token == null || !SupabaseBootstrap.isInitialized) {
      return;
    }
    try {
      await _crud.createOrUpdate(
        collection: AppCollections.fcmTokens,
        docId: user.username,
        data: {
          'token': token,
          'username': user.username,
          'roleKey': user.roleKey,
          'schoolId': user.schoolId ?? AuthService.activeSchoolId,
          'platform': defaultTargetPlatform.name,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FcmService._saveTokenForCurrentUser: $e');
      }
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    unawaited(
      PushNotificationService.instance.showTrayNotification(
        title: notification.title ?? 'MayaBela',
        body: notification.body ?? '',
      ),
    );
  }

  void _onOpenedFromTray(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FcmService: opened from notification — ${message.data}');
    }
  }
}

/// Background handler — must be top-level. FCM shows notification payloads
/// automatically when the app is backgrounded or killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
