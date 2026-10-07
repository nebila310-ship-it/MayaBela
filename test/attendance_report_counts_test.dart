import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'admin.mal838',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'MAL838',
      fullName: 'Nabil Ahmed',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('dashboard and daily report match the live 17/18 register', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1A-REP';
    final day = DateTime.now();

    for (var i = 1; i <= 18; i++) {
      final student = StudentRegistryService.instance.addStudent(
        schoolId: 'MAL838',
        fullName: 'Student $i',
        grade: 'KG',
        className: className,
        dateOfBirth: DateTime(2019, 1, i.clamp(1, 28)),
      );
      data.syncChildFromRegistry(student.studentId);
    }

    final view = data.attendanceRegisterView(className: className, date: day);
    expect(view.entries, hasLength(18));
    view.entries.last.status = AttendanceStatus.absent;
    view.entries.last.updatedAt = DateTime.now();

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Homeroom',
        notifyParents: false,
        entries: view.entries,
      ),
      isTrue,
    );

    final live = data.attendanceRegisterView(className: className, date: day);
    final present = live.entries
        .where((e) => e.status == AttendanceStatus.present)
        .length;
    final absent = live.entries
        .where((e) => e.status == AttendanceStatus.absent)
        .length;
    expect(present, 17);
    expect(absent, 1);

    final report = data.buildDailyAttendanceReport(day);
    expect(report.presentCount, 17);
    expect(report.absentCount, 1);
    expect(report.lateCount, 0);
    expect(
      report.sessions.where((s) => s.className == className),
      hasLength(1),
    );
    expect(report.records, hasLength(18));

    final stats = WebAdminStatsService.instance.load();
    expect(stats.studentsPresentToday, 17);
    expect(stats.studentsAbsent, 1);
  });

  test('leftover demo 1-present-2-absent sessions do not hide the live class', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1B-REP';
    final day = DateTime(2026, 9, 15);

    for (var i = 1; i <= 18; i++) {
      final student = StudentRegistryService.instance.addStudent(
        schoolId: 'MAL838',
        fullName: 'Live $i',
        grade: 'KG',
        className: className,
        dateOfBirth: DateTime(2019, 2, i.clamp(1, 28)),
      );
      data.syncChildFromRegistry(student.studentId);
    }

    final view = data.attendanceRegisterView(className: className, date: day);
    view.entries[0].status = AttendanceStatus.absent;
    view.entries[0].updatedAt = DateTime.now();
    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Homeroom',
        notifyParents: false,
        entries: view.entries,
      ),
      isTrue,
    );

    final report = data.buildDailyAttendanceReport(day);
    expect(
      report.sessions.any((s) => s.className == 'Grade 4A'),
      isFalse,
    );
    expect(
      report.sessions.any((s) => s.className == 'Grade 5B'),
      isFalse,
    );
    expect(report.presentCount, 17);
    expect(report.absentCount, 1);
  });

  test('partial save still reports the full class list as present', () {
    final data = SchoolDataService.instance;
    const className = 'KG 1C-REP';
    final day = DateTime(2026, 9, 16);

    for (var i = 1; i <= 18; i++) {
      final student = StudentRegistryService.instance.addStudent(
        schoolId: 'MAL838',
        fullName: 'Partial $i',
        grade: 'KG',
        className: className,
        dateOfBirth: DateTime(2019, 3, i.clamp(1, 28)),
      );
      data.syncChildFromRegistry(student.studentId);
    }

    final first = StudentRegistryService.instance.studentsForClass(
      className,
      schoolId: 'MAL838',
    ).first;

    expect(
      data.saveAttendanceSession(
        className: className,
        date: day,
        conductedBy: 'Homeroom',
        notifyParents: false,
        entries: [
          StudentAttendanceEntry(
            studentName: first.fullName,
            studentId: first.studentId,
            status: AttendanceStatus.absent,
            updatedAt: DateTime.now(),
          ),
        ],
      ),
      isTrue,
    );

    final stored = data.getAttendanceSession(className, day)!;
    expect(stored.entries, hasLength(1));

    final report = data.buildDailyAttendanceReport(day);
    expect(report.presentCount, 17);
    expect(report.absentCount, 1);
  });
}
