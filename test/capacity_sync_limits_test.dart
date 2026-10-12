import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/community_photo_service.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/utils/attachment_size_limit.dart';

void main() {
  test('phase 1 pages cloud reads so a 1000-row API cap cannot hide students', () {
    expect(DocumentStore.readPageSize, 1000);
    expect(DocumentStore.pageRange(0), (0, 999));
    expect(DocumentStore.pageRange(1), (1000, 1999));
    expect(DocumentStore.shouldFetchNextPage(1000), isTrue);
    expect(DocumentStore.shouldFetchNextPage(960), isFalse);

    final store = File('lib/services/cloud/document_store.dart').readAsStringSync();
    expect(store, contains('_readPagedRows'));
    expect(store, contains('.range(from, to)'));
    expect(store, contains("order('doc_id')"));
  });

  test('phase 2 logout clears GPS, voice, and in-memory file caches', () {
    final cleanup =
        File('lib/services/session_resource_cleanup.dart').readAsStringSync();
    expect(cleanup, contains('BusLiveLocationService.instance.stopSharing'));
    expect(cleanup, contains('VoiceMessageService.instance.cancelRecording'));
    expect(cleanup, contains('WebAttachmentCache.instance.clear'));
    expect(cleanup, contains('StudentPhotoService.instance.clearMemoryCache'));
    expect(cleanup, contains('TeacherPhotoService.instance.clearMemoryCache'));
    expect(cleanup, contains('DriverPhotoService.instance.clearMemoryCache'));

    final auth = File('lib/services/auth_service.dart').readAsStringSync();
    expect(auth, contains('SessionResourceCleanup.onLogout'));

    final cache = WebAttachmentCache.instance;
    cache.remember('web://demo/a.jpg', Uint8List.fromList([1, 2, 3]));
    expect(cache.cachedCount, greaterThan(0));
    cache.clear();
    expect(cache.cachedCount, 0);

    StudentPhotoService.instance.rememberBytes(
      'STU-1',
      Uint8List.fromList([9]),
    );
    StudentPhotoService.instance.clearMemoryCache();
    expect(StudentPhotoService.instance.lookupBytes('STU-1'), isNull);

    TeacherPhotoService.instance.clearMemoryCache();
    DriverPhotoService.instance.clearMemoryCache();
    CommunityPhotoService.instance.clearMemoryCache();
  });

  test('phase 3 inventory and voice use the same 8/10/25 MB caps', () {
    expect(AttachmentSizeLimit.exceeds('stock.png', 8 * 1024 * 1024 + 1), isTrue);
    expect(
      AttachmentSizeLimit.exceeds('invoice.pdf', 10 * 1024 * 1024 + 1),
      isTrue,
    );
    expect(
      AttachmentSizeLimit.exceeds('voice_message.m4a', 10 * 1024 * 1024 + 1),
      isTrue,
    );
    expect(AttachmentSizeLimit.maxMbForFileName('voice_message.m4a'), 10);

    final inventory =
        File('lib/services/inventory_storage_service.dart').readAsStringSync();
    expect(inventory, contains('AttachmentSizeLimit.exceeds'));
    expect(inventory, contains('lastPickError'));

    final voice =
        File('lib/services/voice_message_service.dart').readAsStringSync();
    expect(voice, contains('AttachmentSizeLimit.exceeds'));
    expect(voice, contains('voice_message.m4a'));
  });
}
