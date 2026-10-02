import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';

/// Attendance Phase 2: student-id rows, save RBAC, register lock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    AuthService.currentUser = null;
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
  });

  test('save hydrates studentId and snapshot survives a name change', () {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.p2',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    final data = SchoolDataService.instance;
    const className = 'Grade 4A';
    final day = DateTime.utc(2026, 11, 2);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele',
            status: AttendanceStatus.present,
          ),
        ],
      ),
      isTrue,
    );

    final stored = data.getAttendanceSession(className, day)!;
    expect(stored.entries.single.studentId, 'STU-1001');

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day.add(const Duration(days: 1)),
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele Renamed',
            studentId: 'STU-1001',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
      isTrue,
    );

    final snap = data.attendanceSnapshotForStudent(
      studentName: 'Sara Bekele Renamed',
      className: className,
      studentId: 'STU-1001',
    );
    expect(snap.present, greaterThanOrEqualTo(1));
    expect(snap.absent, greaterThanOrEqualTo(1));

    final mapped = AppDataMaps.attendanceSessionToMap(stored);
    expect(mapped['locked'], isFalse);
    expect((mapped['entries'] as List).first['studentId'], 'STU-1001');
    final roundTrip = AppDataMaps.attendanceSessionFromMap(mapped);
    expect(roundTrip.entries.single.studentId, 'STU-1001');
  });

  test('parent cannot write the register; assigned teacher cannot mark another class', () {
    final data = SchoolDataService.instance;
    final day = DateTime.utc(2026, 11, 4);

    AuthService.currentUser = RegisteredUser(
      username: 'parent.p2',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(data.canWriteAttendanceRegister('Grade 4A'), isFalse);
    expect(
      data.saveAttendanceSession(
        className: 'Grade 4A',
        date: day,
        conductedBy: 'Parent',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
      isFalse,
    );
    expect(data.getAttendanceSession('Grade 4A', day), isNull);

    AuthService.currentUser = RegisteredUser(
      username: 'teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      linkedTeacherId: 'TCH-1001',
    );
    expect(data.canWriteAttendanceRegister('Grade 4A'), isTrue);
    expect(data.canWriteAttendanceRegister('Grade 9Z-P2X'), isFalse);
    expect(
      data.saveAttendanceSession(
        className: 'Grade 9Z-P2X',
        date: day,
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Out Of Scope',
            status: AttendanceStatus.present,
          ),
        ],
      ),
      isFalse,
    );
    expect(data.getAttendanceSession('Grade 9Z-P2X', day), isNull);
  });

  test('locked register blocks the teacher; admin can unlock', () {
    final data = SchoolDataService.instance;
    const className = 'Grade 4A';
    final day = DateTime.utc(2026, 11, 5);

    AuthService.currentUser = RegisteredUser(
      username: 'teacher',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      linkedTeacherId: 'TCH-1001',
    );
    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele',
            status: AttendanceStatus.present,
          ),
        ],
      ),
      isTrue,
    );
    expect(
      data.lockAttendanceSession(className: className, date: day),
      isTrue,
    );
    expect(data.getAttendanceSession(className, day)!.locked, isTrue);
    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Miss Belen',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Sara Bekele',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
      isFalse,
    );
    expect(
      data.getAttendanceSession(className, day)!.entries.single.status,
      AttendanceStatus.present,
    );
    expect(data.canUnlockAttendanceRegister(), isFalse);
    expect(
      data.unlockAttendanceSession(className: className, date: day),
      isFalse,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'admin.p2',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    expect(data.canUnlockAttendanceRegister(), isTrue);
    expect(
      data.unlockAttendanceSession(className: className, date: day),
      isTrue,
    );
    expect(data.getAttendanceSession(className, day)!.locked, isFalse);
  });
}
