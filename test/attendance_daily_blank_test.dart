import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const className = 'Grade 3A-BLANK';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final data = SchoolDataService.instance;
    data.debugAttendanceNow = null;
    data.debugEnforceAttendanceWindow = null;
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.blank',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'MAL838',
      fullName: 'Ms Hana',
    );
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-BLANK-A',
        fullName: 'Blank Alpha',
        grade: 'Grade 3',
        className: className,
        schoolId: 'MAL838',
        dateOfBirth: DateTime(2014, 1, 1),
      ),
      AdminStudentRecord(
        studentId: 'STU-BLANK-B',
        fullName: 'Blank Beta',
        grade: 'Grade 3',
        className: className,
        schoolId: 'MAL838',
        dateOfBirth: DateTime(2014, 2, 2),
      ),
    ]);
  });

  tearDown(() {
    final data = SchoolDataService.instance;
    data.debugAttendanceNow = null;
    data.debugEnforceAttendanceWindow = null;
    AuthService.currentUser = null;
  });

  test('a new day is blank even when yesterday was absent', () {
    final data = SchoolDataService.instance;
    final yesterday = DateTime(2026, 10, 12);
    final today = DateTime(2026, 10, 13);

    expect(
      data.saveAttendanceSession(
        className: className,
        date: yesterday,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Blank Alpha',
            studentId: 'STU-BLANK-A',
            status: AttendanceStatus.absent,
            updatedAt: yesterday,
          ),
        ],
      ),
      isTrue,
    );

    final view = data.attendanceRegisterView(className: className, date: today);
    expect(view.entries, hasLength(2));
    expect(
      view.entries.every((e) => e.status == AttendanceStatus.unmarked),
      isTrue,
    );
    expect(view.conductedBy, isNull);
    expect(
      data.classesWithoutConductedAttendance(today),
      contains(className),
    );
  });

  test('the daily register locks at 9:00 and blocks a teacher', () {
    final data = SchoolDataService.instance;
    data.debugEnforceAttendanceWindow = true;
    final morning = DateTime(2026, 10, 14, 8, 45);
    data.debugAttendanceNow = morning;

    expect(data.attendanceTakingOpen(morning), isTrue);
    expect(
      data.saveAttendanceSession(
        className: className,
        date: morning,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Blank Alpha',
            studentId: 'STU-BLANK-A',
            status: AttendanceStatus.present,
            updatedAt: morning,
          ),
        ],
      ),
      isTrue,
    );

    final closed = DateTime(2026, 10, 14, 9, 0);
    data.debugAttendanceNow = closed;
    expect(data.attendanceTakingOpen(closed), isFalse);
    expect(
      data.saveAttendanceSession(
        className: className,
        date: closed,
        conductedBy: 'Ms Hana',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: 'Blank Beta',
            studentId: 'STU-BLANK-B',
            status: AttendanceStatus.absent,
            updatedAt: closed,
          ),
        ],
      ),
      isFalse,
    );

    data.lockClosedDailyAttendance(closed);
    final session = data.getAttendanceSession(className, closed);
    expect(session, isNotNull);
    expect(session!.locked, isTrue);
    expect(
      session.entries
          .firstWhere((e) => e.studentName == 'Blank Alpha')
          .status,
      AttendanceStatus.present,
    );
    expect(
      session.entries.any((e) => e.studentName == 'Blank Beta'),
      isFalse,
    );

    data.upsertStudentQrProfile(
      StudentQrProfile(
        id: 'stu-blank-b',
        name: 'Blank Beta',
        className: className,
        qrCode: 'STUDENT:STU-BLANK-B',
      ),
    );
    expect(
      data.recordQrScan(
        qrCode: 'STUDENT:STU-BLANK-B',
        action: QrScanAction.present,
        scannedBy: 'Ms Hana',
        allowedClassName: className,
        syncAttendance: true,
      ),
      'locked',
    );
  });

  test('a scan before 9:00 marks only that student', () {
    final data = SchoolDataService.instance;
    data.debugEnforceAttendanceWindow = true;
    final morning = DateTime(2026, 10, 15, 8, 40);
    data.debugAttendanceNow = morning;
    data.upsertStudentQrProfile(
      StudentQrProfile(
        id: 'stu-blank-a',
        name: 'Blank Alpha',
        className: className,
        qrCode: 'STUDENT:STU-BLANK-A',
      ),
    );

    expect(
      data.recordQrScan(
        qrCode: 'STUDENT:STU-BLANK-A',
        action: QrScanAction.late,
        scannedBy: 'Ms Hana',
        allowedClassName: className,
        syncAttendance: true,
      ),
      isNull,
    );

    final view = data.attendanceRegisterView(className: className, date: morning);
    expect(
      view.entries.firstWhere((e) => e.studentName == 'Blank Alpha').status,
      AttendanceStatus.late,
    );
    expect(
      view.entries.firstWhere((e) => e.studentName == 'Blank Beta').status,
      AttendanceStatus.unmarked,
    );
    expect(
      data.classesWithoutConductedAttendance(morning),
      isNot(contains(className)),
    );
  });
}
