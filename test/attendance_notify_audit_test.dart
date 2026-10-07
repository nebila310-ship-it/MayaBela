import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.audit',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'FR-001',
      fullName: 'School Admin',
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    NotificationService.instance.resetForTests();
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  test('daily reports drop demo names once the class has a live roster', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-LIVE-01',
        fullName: 'Maya Live',
        grade: '4',
        className: 'Grade 4A',
        schoolId: 'FR-001',
        dateOfBirth: DateTime(2016, 5, 1),
      ),
    ], replace: true);

    final report = SchoolDataService.instance.buildDailyAttendanceReport(
      DateTime.now(),
    );
    expect(report.records.any((r) => r.studentName == 'Sara Bekele'), isFalse);
    expect(report.records.any((r) => r.studentName == 'Maya Live'), isTrue);
  });

  test('saving an absence notifies the linked parent', () {
    expect(
      SchoolDataService.instance.saveAttendanceSession(
        className: 'Grade 8A-AUD',
        date: DateTime.now(),
        conductedBy: 'School Admin',
        entries: [
          StudentAttendanceEntry(
            studentName: 'Roll Kid 02',
            studentId: 'STU-AUD-02',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
      isTrue,
    );

    final notes = NotificationService.instance.itemsForTests().where(
      (n) =>
          n.type == NotificationType.attendance &&
          n.body.contains('Roll Kid 02'),
    );
    expect(notes, isNotEmpty);
    expect(notes.first.recipientRole, AuthService.roleParent);
    expect(notes.first.targetStudentId, 'STU-AUD-02');
  });

  test('QR late writes the register and notifies that student\'s parent', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-QR-01',
        fullName: 'Qr LateKid',
        grade: '8',
        className: 'Grade 8Q',
        schoolId: 'FR-001',
        dateOfBirth: DateTime(2012, 3, 3),
      ),
    ], replace: true);

    SchoolDataService.instance.upsertStudentQrProfile(
      StudentQrProfile(
        id: 'STU-QR-01',
        name: 'Qr LateKid',
        className: 'Grade 8Q',
        qrCode: 'STUDENT:STU-QR-01',
      ),
    );

    expect(
      SchoolDataService.instance.recordQrScan(
        qrCode: 'STUDENT:STU-QR-01',
        action: QrScanAction.late,
        scannedBy: 'Gate',
        allowedClassName: 'Grade 8Q',
        syncAttendance: true,
      ),
      isNull,
    );

    final session = SchoolDataService.instance.getAttendanceSession(
      'Grade 8Q',
      DateTime.now(),
    );
    expect(session, isNotNull);
    expect(
      session!.entries.firstWhere((e) => e.studentName == 'Qr LateKid').status,
      AttendanceStatus.late,
    );

    final notes = NotificationService.instance.itemsForTests().where(
      (n) => n.body.contains('Qr LateKid'),
    );
    expect(
      notes.any(
        (n) =>
            n.type == NotificationType.attendance &&
            n.recipientRole == AuthService.roleParent &&
            n.targetStudentId == 'STU-QR-01',
      ),
      isTrue,
    );
    expect(
      notes.any(
        (n) =>
            n.type == NotificationType.qrScan &&
            n.targetStudentId == 'STU-QR-01' &&
            n.targetClassName == 'Grade 8Q',
      ),
      isTrue,
    );
  });
}
