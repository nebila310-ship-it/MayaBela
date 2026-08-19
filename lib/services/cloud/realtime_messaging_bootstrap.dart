import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud/conversation_realtime_sync.dart';
import 'package:mayabela/services/cloud/fcm_service.dart';
import 'package:mayabela/services/cloud/inventory_realtime_sync.dart';
import 'package:mayabela/services/cloud/staff_content_realtime_sync.dart';
import 'package:mayabela/services/cloud/student_realtime_sync.dart';
import 'package:mayabela/services/cloud/transport_realtime_sync.dart';

/// Optional realtime acceleration — [CloudSyncEngine] remains the 5s source of truth.
abstract final class RealtimeMessagingBootstrap {
  static Future<void> onSessionStarted() async {
    await FcmService.instance.registerForCurrentUser();
    if (!CloudSyncFlags.enabled) return;

    final role = AuthService.currentUser?.roleKey;
    ConversationRealtimeSync.instance.start();
    StaffContentRealtimeSync.start();

    if (role == AuthService.roleStudent) {
      StudentRealtimeSync.start();
    }
    if (role == AuthService.roleDriver ||
        role == AuthService.roleParent ||
        role == AuthService.roleAdmin ||
        role == AuthService.roleTeacher) {
      TransportRealtimeSync.start();
    }
    if (role == AuthService.roleAdmin || role == AuthService.roleTeacher) {
      InventoryRealtimeSync.start();
    }
  }

  static Future<void> onSessionEnded() async {
    ConversationRealtimeSync.instance.stop();
    StaffContentRealtimeSync.stop();
    StudentRealtimeSync.stop();
    TransportRealtimeSync.stop();
    InventoryRealtimeSync.stop();
    await FcmService.instance.clearTokenForCurrentUser();
  }

  static Future<void> onAppBoot({required bool sessionRestored}) async {
    await FcmService.instance.init();
    if (sessionRestored &&
        AuthService.currentUser != null &&
        CloudSyncFlags.enabled) {
      await onSessionStarted();
    }
  }
}
