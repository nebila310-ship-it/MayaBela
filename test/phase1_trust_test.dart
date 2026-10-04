import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/library_rental_service.dart';
import 'package:mayabela/services/material_access_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_password_reset_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    StudentPasswordResetStore.instance.resetForTests();
    MaterialAccessService.instance.reset();
  });

  tearDown(() {
    AuthService.currentUser = null;
    StudentPasswordResetStore.instance.resetForTests();
    MaterialAccessService.instance.reset();
  });

  test('web calendar uses the signed-in role unless the desk can read all', () {
    final page = read('lib/web_erp/pages/web_calendar_page.dart');
    expect(page, contains('getVisibleCalendarEventsForRole'));
    expect(page, contains('AuthService.mayReadAllSchoolData'));
    expect(page, contains('AuthService.currentUser?.roleKey'));
    expect(
      page.contains(
        'getVisibleCalendarEventsForRole(\n      AuthService.roleAdmin',
      ),
      isFalse,
    );
  });

  test('parents-only calendar events stay hidden from classroom teachers', () {
    final event = SchoolDataService.instance.scheduleCalendarEvent(
      title: 'Phase1 parents briefing',
      description: 'Trust calendar filter',
      date: DateTime(2026, 10, 4),
      type: CalendarEventType.meeting,
      audience: 'parents',
      autoAnnounce: false,
    );
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleParent,
      ),
      isTrue,
    );
    expect(
      SchoolDataService.instance.calendarEventVisibleToRole(
        event,
        AuthService.roleTeacher,
      ),
      isFalse,
    );
    expect(
      SchoolDataService.instance
          .getVisibleCalendarEventsForRole(AuthService.roleAdmin)
          .any((row) => row.id == event.id),
      isTrue,
    );
    expect(
      SchoolDataService.instance
          .getVisibleCalendarEventsForRole(AuthService.roleTeacher)
          .any((row) => row.id == event.id),
      isFalse,
    );
  });

  test('office full-access desk is treated as school-wide calendar reader', () {
    AuthService.currentUser = RegisteredUser(
      username: 'office.desk',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.fullAccess],
    );
    expect(AuthService.mayReadAllSchoolData, isTrue);

    AuthService.currentUser = RegisteredUser(
      username: 'class.teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(AuthService.mayReadAllSchoolData, isFalse);
  });

  test('student password reset requests merge by stable school id', () async {
    final first = await StudentPasswordResetStore.instance.submit(
      studentId: 'STU-1001',
      schoolId: 'TB-001',
      username: 'kidus',
      studentName: 'Kidus',
    );
    expect(first.id, 'spr-TB-001-STU-1001');
    expect(
      StudentPasswordResetStore.instance.pendingForSchool('TB-001'),
      hasLength(1),
    );

    final again = await StudentPasswordResetStore.instance.submit(
      studentId: 'stu-1001',
      schoolId: 'tb-001',
      username: 'kidus',
    );
    expect(again.id, first.id);
    expect(
      StudentPasswordResetStore.instance.pendingForSchool('TB-001'),
      hasLength(1),
    );

    StudentPasswordResetStore.instance.applyPersisted([
      StudentPasswordResetRequest(
        id: first.id,
        studentId: 'STU-1001',
        schoolId: 'TB-001',
        requestedAt: first.requestedAt,
        status: 'resolved',
        resolvedAt: DateTime(2026, 10, 4, 12),
        resolvedBy: 'admin',
      ),
    ]);
    expect(
      StudentPasswordResetStore.instance.pendingForSchool('TB-001'),
      isEmpty,
    );
  });

  test('library and material grants apply from a cloud pull payload', () {
    LibraryRentalService.instance.applyPersisted(
      [
        LibraryRental(
          id: 'rent-phase1',
          materialId: 'book-1',
          bookTitle: 'Amharic reader',
          studentId: 'STU-1001',
          studentName: 'Kidus',
          isPaid: true,
          rentedAt: DateTime(2026, 10, 1),
        ),
      ],
      merge: false,
    );
    expect(
      LibraryRentalService.instance.all.any((row) => row.id == 'rent-phase1'),
      isTrue,
    );

    MaterialAccessService.instance.applyPersisted([
      {'materialId': 'mat-1', 'studentId': 'stu-1001'},
    ]);
    expect(
      MaterialAccessService.instance.unlockedStudentIds('mat-1'),
      contains('STU-1001'),
    );
  });

  test('5s standard lane now includes institution, HR, library and audit', () {
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        AppCollections.institutionRecords,
        AppCollections.driverRegistry,
        AppCollections.employeeRegistry,
        AppCollections.schoolAuditLog,
        AppCollections.libraryRentals,
        AppCollections.libraryCopies,
        AppCollections.campusRooms,
        AppCollections.campusCameras,
        AppCollections.mfaPolicies,
        AppCollections.materialAccess,
        AppCollections.studentPasswordResets,
      ]),
    );

    final store = CloudAppStore.instance;
    for (final collection in [
      AppCollections.libraryRentals,
      AppCollections.libraryCopies,
      AppCollections.materialAccess,
      AppCollections.studentPasswordResets,
    ]) {
      expect(store.pullGroupKeyForTest(collection), isNotNull);
    }

    AuthService.currentUser = RegisteredUser(
      username: 'parent.p1',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll([
        AppCollections.libraryRentals,
        AppCollections.materialAccess,
      ]),
    );
  });

  test('mail preflight and student reset live on the cloud path', () {
    final mailFn = read('supabase/functions/platform-mail-config/index.ts');
    expect(mailFn, contains('public-status'));
    expect(mailFn, contains('configured'));
    expect(mailFn, contains('hasResend'));

    final mailClient = read('lib/services/platform_mail_cloud_service.dart');
    expect(mailClient, contains('publicStatus()'));
    expect(mailClient, contains("'action': 'public-status'"));

    final goLive = read('lib/web_erp/pages/web_go_live_page.dart');
    expect(goLive, contains('MailPreflightCard'));

    final health = read('lib/web_erp/pages/web_system_health_page.dart');
    expect(health, contains('MailPreflightCard'));

    final studentFn = read(
      'supabase/functions/school-request-student-password-reset/index.ts',
    );
    expect(studentFn, contains('student_password_resets'));
    expect(studentFn, contains('findAccountDoc'));
    expect(studentFn, contains('assertNotRateLimited'));

    final store = read('lib/services/student_password_reset_store.dart');
    expect(store, contains('requestStudentPasswordReset('));
    expect(store, contains('requestIdFor'));
  });
}
