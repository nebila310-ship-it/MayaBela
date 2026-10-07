import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/widgets/platform_path_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'native attachment upload reads a local path when picker bytes are empty',
    () async {
      const path = 'web://phase2-circular.pdf';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      WebAttachmentCache.instance.remember(path, bytes);

      final resolved = await AnnouncementAttachmentService.instance
          .resolveUploadBytes(bytes: null, localPath: path);
      expect(resolved, bytes);
    },
  );

  test('private school-files urls are not rewritten as public branding', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/'
        'schools/MAL838/gallery_media/1_photo.jpg';
    expect(ProfilePhotoCodec.isPrivateSchoolFilesUrl(url), isTrue);
    expect(
      ProfilePhotoCodec.schoolFilesObjectPath(url),
      'schools/MAL838/gallery_media/1_photo.jpg',
    );
  });

  testWidgets('gallery/circular preview uses cached private file bytes', (
    tester,
  ) async {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/'
        'schools/MAL838/institution_circular_attachments/1_scan.jpg';
    WebAttachmentCache.instance.remember(
      url,
      Uint8List.fromList(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlatformPathImage(path: url, width: 40, height: 40),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  test('voice notes and community photos upload to school-files', () {
    final voice = File(
      'lib/services/voice_message_service.dart',
    ).readAsStringSync();
    expect(voice, contains('uploadSavedAttachment'));
    expect(voice, contains('message_attachments'));

    final community = File(
      'lib/services/community_photo_service.dart',
    ).readAsStringSync();
    expect(community, contains('community_photos'));
    expect(community, contains('ProfilePhotoCodec.saveBytes'));

    final store = File(
      'lib/services/persistence/cloud_app_store.dart',
    ).readAsStringSync();
    expect(store, contains('_promoteLocalPersonPhotos()'));
    expect(store, contains('promotePendingToCloud()'));
  });
}
