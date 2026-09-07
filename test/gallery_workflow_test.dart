import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/gallery_compose.dart';
import 'package:mayabela/services/gallery_media_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/web_file_utils.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';
import 'package:mayabela/web_erp/pages/web_gallery_page.dart';
import 'package:mayabela/web_erp/router/web_erp_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'gallery.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('gallery posts serialize file attachments', () {
    final postedAt = DateTime.utc(2026, 9, 7, 12);
    final original = GalleryPost(
      id: 'gal-att-1',
      className: 'Grade 4A',
      type: GalleryPostType.note,
      title: 'Sports day',
      caption: 'See the attached schedule',
      authorName: 'School Admin',
      postedAt: postedAt,
      attachmentPaths: const ['gallery_attachments/schedule.pdf'],
    );

    final copy = AppDataMaps.galleryPostFromMap(
      AppDataMaps.galleryPostToMap(original),
    );

    expect(copy.attachmentPaths, ['gallery_attachments/schedule.pdf']);
    expect(copy.title, 'Sports day');
    expect(copy.type, GalleryPostType.note);
  });

  test('addGalleryPost keeps attachments for the class', () {
    SchoolDataService.instance.addGalleryPost(
      className: 'Grade 4A',
      type: GalleryPostType.note,
      title: 'Gallery attachment fixture',
      caption: 'Parents can open the flyer',
      authorName: 'School Admin',
      attachmentPaths: const ['gallery_attachments/flyer.pdf'],
    );

    final posted = SchoolDataService.instance
        .getGalleryForClass('Grade 4A')
        .firstWhere((post) => post.title == 'Gallery attachment fixture');
    expect(posted.attachmentPaths, ['gallery_attachments/flyer.pdf']);
  });

  test('admin sidebar has a Gallery item separate from Events', () {
    final items = webErpNavItemsForCurrentUser();
    final events = items.firstWhere((item) => item.id == 'events');
    final gallery = items.firstWhere((item) => item.id == 'gallery');

    expect(events.label, 'Events');
    expect(gallery.label, 'Gallery');
    expect(ModuleAccess.canView('gallery'), isTrue);
    expect(ModuleAccess.canManage('gallery'), isTrue);
    expect(WebErpRouter.pageFor('gallery'), isA<WebGalleryPage>());
  });

  test('compose allows upload from attachments without title or caption', () {
    final composed = GalleryCompose.resolve(
      title: '',
      caption: '',
      type: GalleryPostType.photo,
      attachments: const ['gallery_attachments/class.jpg'],
    );
    expect(composed.title, 'class.jpg');
    expect(composed.mediaPath, 'gallery_attachments/class.jpg');
    expect(composed.type, GalleryPostType.photo);
    expect(
      GalleryCompose.hasPublishableContent(
        title: '',
        attachments: const ['gallery_attachments/class.jpg'],
      ),
      isTrue,
    );
  });

  test('addGalleryPost with attachments appears in the class list', () {
    SchoolDataService.instance.addGalleryPost(
      className: 'Grade 4A',
      type: GalleryPostType.photo,
      title: 'class.jpg',
      caption: '',
      authorName: 'School Admin',
      mediaPath: 'gallery_attachments/class.jpg',
      attachmentPaths: const ['gallery_attachments/class.jpg'],
    );
    final posted = SchoolDataService.instance
        .getGalleryForClass('Grade 4A')
        .firstWhere((post) => post.mediaPath == 'gallery_attachments/class.jpg');
    expect(posted.title, 'class.jpg');
    expect(posted.attachmentPaths, ['gallery_attachments/class.jpg']);
  });

  test('gallery media persistBytes attaches without hanging', () async {
    final pick = await GalleryMediaService.instance.persistBytes(
      fileName: 'class.jpg',
      bytes: List<int>.filled(64, 9),
    );
    expect(pick, isNotNull);
    expect(pick!.displayName, 'class.jpg');
    expect(pick.filePath, isNotEmpty);
    if (WebAttachmentCache.instance.isWebPath(pick.filePath)) {
      expect(WebAttachmentCache.instance.read(pick.filePath), isNotNull);
    }
  });

  test('missing local files do not pretend to open', () async {
    final opened = await WebFileUtils.openOrDownload(
      filePath: '/missing/gallery.pdf',
      fileName: 'gallery.pdf',
    );
    expect(opened, isFalse);
  });

  testWidgets('admin gallery page lists posts and can add attachments', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 800,
            child: WebGalleryPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('Add Post'), findsOneWidget);

    await tester.tap(find.text('Add Post'));
    await tester.pumpAndSettle();

    expect(find.text('Add to Gallery'), findsOneWidget);
    expect(find.text('Add attachment'), findsOneWidget);
  });
}
