import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/campus_room_service.dart';
import 'package:mayabela/services/cctv/cctv_catalog_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/timetable_conflict_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CampusRoomService.instance.resetForTests();
    await CctvCatalogService.instance.resetForTest();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.p5',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() async {
    CampusRoomService.instance.resetForTests();
    await CctvCatalogService.instance.resetForTest();
    AuthService.currentUser = null;
  });

  test('rooms belong to the campus list and rename with the campus', () async {
    await SchoolRegistryService.instance.load();
    final added = await CampusRoomService.instance.addRoom(
      campusName: 'Main Campus',
      roomName: 'Lab A',
    );
    expect(added, isNotNull);
    expect(
      CampusRoomService.instance.roomsForCampus('Main Campus').single.roomName,
      'Lab A',
    );
    expect(
      await CampusRoomService.instance.addRoom(
        campusName: 'Main Campus',
        roomName: 'lab a',
      ),
      isNull,
    );

    await CampusRoomService.instance.renameCampus(
      from: 'Main Campus',
      to: 'HQ Campus',
    );
    expect(CampusRoomService.instance.roomsForCampus('HQ Campus'), isNotEmpty);
    expect(CampusRoomService.instance.roomsForCampus('Main Campus'), isEmpty);
  });

  test('camera URLs persist and apply from a staff pull payload', () async {
    await CctvCatalogService.instance.ensureLoaded();
    await CctvCatalogService.instance.setLocalStreamUrl(
      siteId: 'TB-001-gate',
      streamUrl: 'https://nvr.school.local/hls/gate.m3u8',
    );
    expect(
      CctvCatalogService.instance
          .sitesForSchool('TB-001')
          .singleWhere((s) => s.id == 'TB-001-gate')
          .streamUrl,
      'https://nvr.school.local/hls/gate.m3u8',
    );

    CctvCatalogService.instance.applyPersisted([
      const CctvCameraSite(
        id: 'cam-hq',
        name: 'Hall',
        location: 'Block A',
        campusName: 'Main Campus',
        streamUrl: 'https://nvr.school.local/hls/hall.m3u8',
      ),
    ], merge: false);
    final hall = CctvCatalogService.instance
        .sitesForSchool('TB-001')
        .singleWhere((s) => s.id == 'cam-hq');
    expect(hall.isWired, isTrue);
    expect(hall.campusName, 'Main Campus');
    expect(
      CctvCatalogService.instance.sitesForCampus('Main Campus', schoolId: 'TB-001'),
      isNotEmpty,
    );
  });

  test('timetable slot keeps room and substitute across persist', () {
    const slot = TimetableSlot(
      id: 'slot-p5',
      kind: TimetableSlotKind.lesson,
      subject: 'Math',
      teacherId: 'T-1',
      teacherName: 'Ms Hana',
      room: 'Main Campus · Lab A',
      substituteTeacherId: 'T-2',
      substituteTeacherName: 'Mr Abel',
    );
    expect(slot.effectiveTeacherId, 'T-2');
    expect(slot.effectiveTeacherName, 'Mr Abel');

    final table = ClassTimetable(
      className: 'Grade 5A',
      homeroomTeacherId: 'T-1',
      homeroomTeacherName: 'Ms Hana',
      updatedAt: DateTime(2026, 10, 4),
      days: {
        'monday': DayTimetable(dayKey: 'monday', slots: [slot]),
      },
    );
    final restored = AppDataMaps.classTimetableFromMap(
      AppDataMaps.classTimetableToMap(table),
    );
    final again = restored.day('monday').slots.single;
    expect(again.room, 'Main Campus · Lab A');
    expect(again.substituteTeacherName, 'Mr Abel');
    expect(again.effectiveTeacherId, 'T-2');
  });

  test('substitute and room collisions are timetable conflicts', () {
    TimetableSlot lesson({
      required String id,
      required String teacher,
      String? substitute,
      String? room,
    }) {
      return TimetableSlot(
        id: id,
        kind: TimetableSlotKind.lesson,
        subject: 'Science',
        teacherId: teacher,
        teacherName: teacher,
        room: room,
        substituteTeacherId: substitute,
        substituteTeacherName: substitute,
      );
    }

    final a = ClassTimetable(
      className: 'Grade 5A',
      homeroomTeacherId: 'T-1',
      homeroomTeacherName: 'Hana',
      updatedAt: DateTime(2026, 10, 4),
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [lesson(id: 'a', teacher: 'T-1', substitute: 'T-COVER')],
        ),
      },
    );
    final b = ClassTimetable(
      className: 'Grade 5B',
      homeroomTeacherId: 'T-2',
      homeroomTeacherName: 'Abel',
      updatedAt: DateTime(2026, 10, 4),
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [lesson(id: 'b', teacher: 'T-COVER')],
        ),
      },
    );
    final cover = TimetableConflictService.detect([a, b]);
    expect(cover, isNotEmpty);
    expect(cover.first.teacherId, 'T-COVER');

    final roomA = ClassTimetable(
      className: 'Grade 6A',
      homeroomTeacherId: 'T-3',
      homeroomTeacherName: 'Sara',
      updatedAt: DateTime(2026, 10, 4),
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [lesson(id: 'c', teacher: 'T-3', room: 'Lab A')],
        ),
      },
    );
    final roomB = ClassTimetable(
      className: 'Grade 6B',
      homeroomTeacherId: 'T-4',
      homeroomTeacherName: 'Yonas',
      updatedAt: DateTime(2026, 10, 4),
      days: {
        'monday': DayTimetable(
          dayKey: 'monday',
          slots: [lesson(id: 'd', teacher: 'T-4', room: 'Lab A')],
        ),
      },
    );
    final rooms = TimetableConflictService.detect([roomA, roomB]);
    expect(rooms.any((c) => c.teacherName.startsWith('Room ')), isTrue);
  });

  test('leftover 30s lane carries campus rooms and cameras, not footage', () {
    expect(CctvCatalogService.storesInMayaBelaCloud, isFalse);
    expect(CctvCatalogService.collection, AppCollections.campusCameras);
    expect(CampusRoomService.collection, AppCollections.campusRooms);
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        AppCollections.campusRooms,
        AppCollections.campusCameras,
      ]),
    );
    expect(CloudSyncEngine.highPriority, isNot(contains(AppCollections.campusCameras)));
  });

  test('campus, CCTV, and timetable desks are wired', () {
    expect(
      read('lib/web_erp/pages/web_campus_management_page.dart'),
      contains('This is the only campus list'),
    );
    expect(
      read('lib/web_erp/pages/web_campus_management_page.dart'),
      contains('Add room'),
    );
    expect(read('lib/web_erp/pages/web_cctv_page.dart'), contains('Add camera'));
    expect(read('lib/screens/class_timetable_screen.dart'), contains('Substitute'));
    expect(read('lib/screens/class_timetable_screen.dart'), contains('labelText: \'Room\''));
    expect(
      read('lib/web_erp/pages/web_school_management_page.dart'),
      contains('The only campus list'),
    );
  });
}
