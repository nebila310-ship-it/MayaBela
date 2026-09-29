import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/platform/web_attachment_cache.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/profile_photo_codec.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/web_erp/pages/web_students_table_page.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/profile_photo_view.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/student_photo_avatar.dart';

/// 1x1 PNG so CircleAvatar can decode preview bytes.
final tinyPng = Uint8List.fromList(const [
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
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthService.currentUser = RegisteredUser(
      username: 'photo.admin',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('device-local photo paths are not treated as cloud urls', () {
    expect(ProfilePhotoCodec.isDeviceLocalPath('web://123/STU-1.jpg'), isTrue);
    expect(
      ProfilePhotoCodec.isDeviceLocalPath('/tmp/student_photos/STU-1.jpg'),
      isTrue,
    );
    expect(
      ProfilePhotoCodec.isDeviceLocalPath('data:image/jpeg;base64,xx'),
      isTrue,
    );
    expect(ProfilePhotoCodec.isDeviceLocalPath(null), isTrue);
    expect(ProfilePhotoCodec.isDeviceLocalPath(''), isTrue);
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/student_photos/STU-1_STU-1.jpg';
    expect(ProfilePhotoCodec.isDeviceLocalPath(url), isFalse);
    expect(
      ProfilePhotoCodec.isDeviceLocalPath(
        'schools/TB-001/student_photos/STU-1_STU-1.jpg',
      ),
      isFalse,
    );
    expect(
      ProfilePhotoCodec.cloudObjectPath(
        schoolId: 'tb-001',
        folder: 'student_photos',
        personId: 'stu-1',
      ),
      'schools/TB-001/student_photos/STU-1_STU-1.jpg',
    );
    expect(
      ProfilePhotoCodec.withoutDeviceLocalPhoto({
        'studentId': 'STU-1',
        'photoPath': 'web://1/STU-1.jpg',
      }),
      {'studentId': 'STU-1'},
    );
    expect(
      ProfilePhotoCodec.withoutDeviceLocalPhoto({
        'studentId': 'STU-1',
        'photoPath': url,
      }),
      {'studentId': 'STU-1', 'photoPath': url},
    );
  });

  test('undecodable bytes are kept so the preview can still show them', () {
    final raw = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(ProfilePhotoCodec.squareJpegOrOriginal(raw), raw);
  });

  test('student photo save stores bytes for later display', () async {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final path = await StudentPhotoService.instance.saveBytesForStudent(
      'STU-PHOTO-1',
      bytes,
    );
    expect(path, isNotNull);
    expect(path, isNotEmpty);
    final looked = StudentPhotoService.instance.lookupBytes(
      'STU-PHOTO-1',
      storedPath: path,
    );
    expect(looked, isNotNull);
    expect(looked, isNotEmpty);
    expect(WebAttachmentCache.instance.read(path), isNotNull);
  });

  test('saved local student photo hydrates from this device cache', () async {
    final bytes = Uint8List.fromList(List<int>.generate(48, (i) => 100 + i));
    final path = await StudentPhotoService.instance.saveBytesForStudent(
      'STU-LOCAL-1',
      bytes,
    );
    expect(path, isNotNull);
    expect(ProfilePhotoCodec.isDeviceLocalPath(path), isTrue);
    final hydrated = await StudentPhotoService.instance.hydrateBytes(
      'STU-LOCAL-1',
      storedPath: path,
    );
    expect(hydrated, isNotNull);
    expect(hydrated, isNotEmpty);
  });

  test('teacher photo save stores bytes for later display', () async {
    final bytes = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
    final path = await TeacherPhotoService.instance.saveBytesForTeacher(
      'TCH-PHOTO-1',
      bytes,
    );
    expect(path, isNotNull);
    expect(
      TeacherPhotoService.instance.lookupBytes('TCH-PHOTO-1', storedPath: path),
      isNotNull,
    );
  });

  testWidgets('enrollment photo picker shows selected bytes', (tester) async {
    final bytes = tinyPng;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminPhotoPicker(
            photoBytes: bytes,
            hint: 'Tap to add photo',
            accent: Colors.indigo,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.text('Tap to add photo'), findsOneWidget);
  });

  testWidgets('student directory photo column uses profile avatars', (
    tester,
  ) async {
    final photoPath = WebAttachmentCache.instance.store(
      'STU-LIST-1.jpg',
      tinyPng,
    );
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-LIST-1',
        fullName: 'Rayan',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 3, 1),
        photoPath: photoPath,
      ),
    ], replace: true);
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebStudentsTablePage())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StaffRegistryAvatar), findsWidgets);
    expect(find.text('Photo'), findsOneWidget);
    final avatar = tester.widget<StaffRegistryAvatar>(
      find.byType(StaffRegistryAvatar).first,
    );
    expect(avatar.photoPath, photoPath);
    expect(avatar.isStudent, isTrue);
  });

  testWidgets('registry avatar paints the stored photo in the circle', (
    tester,
  ) async {
    final photoPath = WebAttachmentCache.instance.store(
      'STU-AV-1.jpg',
      tinyPng,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffRegistryAvatar(
            staffId: 'STU-AV-1',
            name: 'Rayan',
            photoPath: photoPath,
            isStudent: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isNotNull);
  });

  testWidgets('align dialog exposes zoom in and zoom out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showProfilePhotoAlignDialog(context, bytes: tinyPng),
              child: const Text('open-align'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-align'));
    await tester.pumpAndSettle();
    expect(find.text('Align photo'), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('saved photo opens a zoomable viewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProfilePhotoViewer(
                context,
                bytes: tinyPng,
                title: 'Rayan',
              ),
              child: const Text('open-view'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-view'));
    await tester.pumpAndSettle();
    expect(find.text('Rayan'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  test('profile photo provider uses memory bytes', () {
    final bytes = Uint8List.fromList([9, 8, 7]);
    expect(profilePhotoProvider(bytes: bytes), isA<MemoryImage>());
  });

  test('private school-files urls are not loaded as NetworkImage', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/student_photos/STU-1_STU-1.jpg';
    expect(
      ProfilePhotoCodec.schoolFilesObjectPath(url),
      'schools/TB-001/student_photos/STU-1_STU-1.jpg',
    );
    expect(ProfilePhotoCodec.isPrivateSchoolFilesUrl(url), isTrue);
    expect(profilePhotoProvider(path: url), isNull);
  });

  test('branding school-files urls stay public network images', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/branding/logo.jpg';
    expect(ProfilePhotoCodec.isPrivateSchoolFilesUrl(url), isFalse);
    expect(profilePhotoProvider(path: url), isA<NetworkImage>());
  });

  test('cached private school-files url uses memory image', () {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/student_photos/STU-CACHE.jpg';
    WebAttachmentCache.instance.remember(url, tinyPng);
    expect(profilePhotoProvider(path: url), isA<MemoryImage>());
  });

  test('hydrateBytes returns cached remote photo without network', () async {
    const url =
        'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/student_photos/STU-HYDRATE.jpg';
    WebAttachmentCache.instance.remember(url, tinyPng);
    final byteCache = <String, Uint8List>{};
    final pathCache = <String, String>{};
    final bytes = await ProfilePhotoCodec.hydrateBytes(
      personId: 'STU-HYDRATE',
      byteCache: byteCache,
      pathCache: pathCache,
      storedPath: url,
    );
    expect(bytes, isNotNull);
    expect(bytes, isNotEmpty);
    expect(byteCache['STU-HYDRATE'], isNotNull);
  });

  test('registry resolves photo by name and name slug', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-RAYAN-1',
        fullName: 'Rayan Ahmed',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 3, 1),
        photoPath:
            'https://example.supabase.co/storage/v1/object/public/school-files/schools/TB-001/student_photos/x.jpg',
      ),
    ], replace: true);

    expect(
      StudentRegistryService.instance
          .resolveForPhoto(name: 'rayan ahmed')
          ?.studentId,
      'STU-RAYAN-1',
    );
    expect(
      StudentRegistryService.instance
          .resolveForPhoto(studentId: 'rayan-ahmed')
          ?.studentId,
      'STU-RAYAN-1',
    );
  });

  testWidgets('student photo avatar looks up saved registry photo by name', (
    tester,
  ) async {
    final photoPath = WebAttachmentCache.instance.store(
      'STU-NAME-1.jpg',
      tinyPng,
    );
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-NAME-1',
        fullName: 'Liya Solomon',
        grade: 'Grade 4',
        className: 'Grade 4A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2015, 1, 1),
        photoPath: photoPath,
      ),
    ], replace: true);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudentPhotoAvatar(name: 'Liya Solomon', radius: 16),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatar = tester.widget<StaffRegistryAvatar>(
      find.byType(StaffRegistryAvatar),
    );
    expect(avatar.staffId, 'STU-NAME-1');
    expect(avatar.photoPath, photoPath);
    expect(avatar.isStudent, isTrue);
    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isNotNull);
  });
}
