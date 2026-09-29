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

  /// 1x1 PNG so CircleAvatar can decode preview bytes.
  final tinyPng = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
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
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-LIST-1',
        fullName: 'Rayan',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: 'TB-001',
        dateOfBirth: DateTime(2016, 3, 1),
      ),
    ]);
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WebStudentsTablePage())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StaffRegistryAvatar), findsWidgets);
    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('align dialog exposes zoom in and zoom out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProfilePhotoAlignDialog(
                context,
                bytes: tinyPng,
              ),
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
}
