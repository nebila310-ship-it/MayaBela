import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/timetable_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.clearCloudAccessScope();
  });

  test('studentsForClass treats 5B and Grade 5B as the same roster', () {
    final roster = StudentRegistryService.instance.studentsForClass('5B');
    expect(roster.map((s) => s.studentId), contains('STU-1005'));
    expect(
      roster.any((s) => s.fullName == 'Liya Solomon'),
      isTrue,
    );
  });

  test('gallery, attendance, and daily activity filters honor class aliases', () {
    final date = DateTime.utc(2026, 9, 4);
    SchoolDataService.instance.applyPersistedGallery([
      GalleryPost(
        id: 'GAL-P6-1',
        className: 'Grade 5B',
        type: GalleryPostType.photo,
        title: 'Science fair',
        caption: 'Grade 5B projects',
        authorName: 'Abebe',
        postedAt: date,
      ),
    ]);
    SchoolDataService.instance.applyPersistedAttendance([
      AttendanceSession(
        className: 'Grade 5B',
        date: date,
        conductedBy: 'Abebe',
        entries: const [],
      ),
    ]);
    SchoolDataService.instance.applyPersistedDailyActivities([
      DailyActivityReport(
        id: 'DA-P6-1',
        studentId: 'STU-1005',
        studentName: 'Liya Solomon',
        className: 'Grade 5B',
        date: date,
        selectedOptionIds: const ['focus'],
        teacherComment: 'Good day',
        teacherName: 'Abebe',
      ),
    ]);

    expect(
      SchoolDataService.instance.getGalleryForClass('5B').map((p) => p.id),
      contains('GAL-P6-1'),
    );
    expect(
      SchoolDataService.instance.getAttendanceSession('5B', date)?.className,
      'Grade 5B',
    );
    expect(
      SchoolDataService.instance
          .getDailyActivitiesForClass('5B')
          .map((r) => r.id),
      contains('DA-P6-1'),
    );
  });

  test('parent fees only include linked children, not the full demo roster', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.phase6',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );

    final fees = SchoolDataService.instance.getFeesForParent();
    expect(fees.map((f) => f.studentId), everyElement('STU-1001'));
    expect(fees.map((f) => f.studentName).toSet(), {'Sara Bekele'});
    expect(fees.any((f) => f.studentId == 'STU-1002'), isFalse);
    expect(fees.any((f) => f.studentId == 'STU-1003'), isFalse);
  });

  test('in-app parent notifications honor targetClassName aliases', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.phase6.notify',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );

    NotificationService.instance.applyCloudNotifications([
      AppNotification(
        id: 'n-p6-5b',
        title: 'Homework posted',
        body: 'Science for Grade 5B',
        type: NotificationType.homework,
        fromRole: AuthService.roleTeacher,
        fromName: 'Abebe',
        recipientRole: AuthService.roleParent,
        createdAt: DateTime.now(),
        targetClassName: 'Grade 5B',
      ),
      AppNotification(
        id: 'n-p6-4a',
        title: 'Homework posted',
        body: 'Math for Grade 4A',
        type: NotificationType.homework,
        fromRole: AuthService.roleTeacher,
        fromName: 'Belen',
        recipientRole: AuthService.roleParent,
        createdAt: DateTime.now(),
        targetClassName: '4A',
      ),
      AppNotification(
        id: 'n-p6-all',
        title: 'School closed Saturday',
        body: 'Staff training day',
        type: NotificationType.announcement,
        fromRole: AuthService.roleAdmin,
        fromName: 'Office',
        recipientRole: AuthService.roleParent,
        createdAt: DateTime.now(),
      ),
    ]);

    final ids = NotificationService.instance
        .notificationsForCurrentUser()
        .map((n) => n.id)
        .toSet();
    expect(ids, contains('n-p6-4a'));
    expect(ids, contains('n-p6-all'));
    expect(ids, isNot(contains('n-p6-5b')));
    expect(ids, contains('seed-1'));
  });

  test('parent of Grade 5B sees aliased class alerts and not Grade 4A homework', () {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.phase6.liya',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1005'],
    );

    NotificationService.instance.applyCloudNotifications([
      AppNotification(
        id: 'n-p6-liya-5b',
        title: 'Gallery posted',
        body: 'Photos for 5B',
        type: NotificationType.gallery,
        fromRole: AuthService.roleTeacher,
        fromName: 'Abebe',
        recipientRole: AuthService.roleParent,
        createdAt: DateTime.now(),
        targetClassName: '5B',
      ),
    ]);

    final ids = NotificationService.instance
        .notificationsForCurrentUser()
        .map((n) => n.id)
        .toSet();
    expect(ids, contains('n-p6-liya-5b'));
    expect(ids, isNot(contains('seed-1')));
  });

  test('parent and driver packs include boarding backup; highPriority stays lean', () {
    expect(
      CloudSyncEngine.highPriority,
      isNot(contains(AppCollections.transportPassengerStatus)),
    );
    expect(
      CloudSyncEngine.highPriority,
      isNot(contains(AppCollections.transportScans)),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.phase6.bus',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll([
        AppCollections.transportPassengerStatus,
        AppCollections.transportScans,
      ]),
    );
    expect(
      CloudSyncEngine.probeCollectionsForTick(2),
      containsAll([
        AppCollections.busLivePositions,
        AppCollections.transportPassengerStatus,
        AppCollections.transportScans,
      ]),
    );
    expect(
      CloudSyncEngine.probeCollectionsForTick(1),
      isNot(contains(AppCollections.transportPassengerStatus)),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'driver.phase6',
      password: 'x',
      roleKey: AuthService.roleDriver,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll([
        AppCollections.transportPassengerStatus,
        AppCollections.transportScans,
      ]),
    );
  });

  test('parent-link approve is managers or classroom teachers, never staffs', () {
    final link = ParentLinkRequest(
      id: 'PL-P6-1',
      parentUsername: 'parent.phase6.link',
      parentFullName: 'Liya Parent',
      studentId: 'STU-1005',
      schoolId: 'TB-001',
      relationship: ParentRelationship.mother,
      requestedAt: DateTime.utc(2026, 9, 1),
      className: 'Grade 5B',
    );
    final previous = EnrollmentService.instance.allLinksSnapshot();
    final previousNext = EnrollmentService.instance.nextLinkIdCounter;
    EnrollmentService.instance.replaceLinks([link], nextId: 20);
    addTearDown(() {
      EnrollmentService.instance.replaceLinks(
        previous,
        nextId: previousNext,
      );
    });

    AuthService.currentUser = RegisteredUser(
      username: 'sa.phase6',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.studentAffairs],
    );
    expect(ModuleAccess.canManage('parents'), isTrue);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(link),
      isTrue,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'staffs.phase6',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.staffs],
    );
    AuthService.applyCloudAccessScope(assignedClassNames: const ['5B']);
    expect(AuthService.isAdministrationStaff, isTrue);
    expect(ModuleAccess.canManage('parents'), isFalse);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(link),
      isFalse,
    );

    AuthService.clearCloudAccessScope();
    AuthService.currentUser = RegisteredUser(
      username: 'homeroom.phase6',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    AuthService.applyCloudAccessScope(assignedClassNames: const ['5B']);
    expect(AuthService.isClassroomTeacher, isTrue);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(link),
      isTrue,
    );

    AuthService.applyCloudAccessScope(assignedClassNames: const ['4A']);
    expect(
      EnrollmentService.instance.canCurrentUserManageParentLink(link),
      isFalse,
    );
  });

  test('getOrCreateForClass reuses an aliased timetable instead of a second one', () {
    TimetableService.instance.applyPersistedTimetables([
      ClassTimetable(
        className: 'Grade 5B',
        homeroomTeacherId: 'TCH-P6',
        homeroomTeacherName: 'Abebe',
        days: const {},
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    ]);
    final first = TimetableService.instance.getOrCreateForClass('5B');
    final second = TimetableService.instance.getOrCreateForClass('Grade 5B');
    expect(first.className, 'Grade 5B');
    expect(second.className, 'Grade 5B');
    expect(
      TimetableService.instance
          .allPersistedTimetables()
          .where((t) => StudentRegistryService.classNamesMatch(t.className, '5B'))
          .length,
      1,
    );
  });

  test('fee pay copy does not claim a live Telebirr settlement', () {
    final s = AppStrings('en');
    expect(s.feeRecordedOnThisDevice, contains('office'));
    expect(s.feeRecordedOnThisDevice.toLowerCase(), isNot(contains('telebirr')));
    expect(s.paymentSuccessVia('Telebirr'), contains('Telebirr'));
  });
}
