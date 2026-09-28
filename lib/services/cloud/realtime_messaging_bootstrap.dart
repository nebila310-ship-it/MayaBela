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
    if (AuthService.currentUser == null) return;
    final generation = AuthService.sessionGeneration;
    await FcmService.instance.registerForCurrentUser();
    if (!AuthService.isLiveGeneration(generation)) return;
    if (!CloudSyncFlags.enabled) return;
    _startLiveChannels();
  }

  /// Drop live sockets so an idle / hidden tab stops billing PostgREST.
  static void pauseLive() {
    ConversationRealtimeSync.instance.stop();
    StaffContentRealtimeSync.stop();
    StudentRealtimeSync.stop();
    TransportRealtimeSync.stop();
    InventoryRealtimeSync.stop();
  }

  /// Re-open role channels after the user comes back. Does not re-register FCM.
  static void resumeLive() {
    if (AuthService.currentUser == null) return;
    if (!CloudSyncFlags.enabled) return;
    _startLiveChannels();
  }

  static void _startLiveChannels() {
    final role = AuthService.currentUser?.roleKey;
    ConversationRealtimeSync.instance.start();
    StaffContentRealtimeSync.start();

    if (role == AuthService.roleStudent) {
      StudentRealtimeSync.start();
    }
    // Messages / GPS / notifications / passenger status apply locally.
    if (role != null) {
      TransportRealtimeSync.start();
    }
    if (role == AuthService.roleAdmin || role == AuthService.roleTeacher) {
      InventoryRealtimeSync.start();
    }
  }

  static Future<void> onSessionEnded() async {
    final generation = AuthService.sessionGeneration;
    ConversationRealtimeSync.instance.stop();
    StaffContentRealtimeSync.stop();
    StudentRealtimeSync.stop();
    TransportRealtimeSync.stop();
    InventoryRealtimeSync.stop();
    if (!AuthService.isCurrentGeneration(generation)) return;
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
