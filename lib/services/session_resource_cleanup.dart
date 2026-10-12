import 'dart:async';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/community_photo_service.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/voice_message_service.dart';

/// Stops device/RAM work that must not outlive a signed-in session.
abstract final class SessionResourceCleanup {
  static Future<void> onLogout() async {
    await BusLiveLocationService.instance.stopSharing();
    await VoiceMessageService.instance.cancelRecording();
    WebAttachmentCache.instance.clear();
    StudentPhotoService.instance.clearMemoryCache();
    TeacherPhotoService.instance.clearMemoryCache();
    DriverPhotoService.instance.clearMemoryCache();
    CommunityPhotoService.instance.clearMemoryCache();
  }
}
