import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/widgets/admin_student_qr_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-1001',
        fullName: 'Sara Bekele',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: 'FR-001',
        dateOfBirth: DateTime(2016, 3, 3),
      ),
    ], replace: true);
  });

  test('each student gets a stable STUDENT:STU-XXXX QR payload', () {
    expect(
      TransportService.qrCodeForStudentId('stu-1001'),
      'STUDENT:STU-1001',
    );
    final profile = qrProfileForStudent(
      StudentRegistryService.instance.lookupById('STU-1001')!,
    );
    expect(profile.qrCode, 'STUDENT:STU-1001');
    expect(profile.name, 'Sara Bekele');
  });

  test('bus and attendance scanners resolve the generated payload', () {
    expect(
      TransportService.instance.resolveStudentIdFromQr('STUDENT:STU-1001'),
      'STU-1001',
    );
  });

  test('a portal username is not treated as a student QR', () {
    expect(
      TransportService.instance.resolveStudentIdFromQr('sara1001'),
      isNull,
    );
  });

  test('a signed-in school scanner does not list demo QR accounts', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.fr',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'FR-001',
      fullName: 'Ms Hana',
    );
    AuthService.sessionSchoolId = 'FR-001';
    addTearDown(() {
      AuthService.currentUser = null;
      AuthService.sessionSchoolId = null;
    });

    final data = SchoolDataService.instance;
    final profiles = data.getAllStudentQrProfiles();
    expect(profiles.map((profile) => profile.id), ['stu-1001']);
    expect(profiles.map((profile) => profile.qrCode), ['STUDENT:STU-1001']);
    expect(
      profiles.map((profile) => profile.id),
      isNot(contains('sara-bekele')),
    );
    expect(data.findStudentByQrCode('STUDENT:sara-bekele'), isNull);
    expect(data.findStudentByQrCode('STUDENT:kidus-bekele'), isNull);
    expect(data.findStudentByQrCode('STUDENT:STU-1001')?.name, 'Sara Bekele');
    expect(
      data.getQrScanHistory().map((record) => record.studentId),
      isNot(contains('sara-bekele')),
    );
  });

  test('a teacher can scan only the students in their own class', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.fr',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'FR-001',
      fullName: 'Ms Hana',
      linkedTeacherId: 'TCH-9001',
    );
    AuthService.sessionSchoolId = 'FR-001';
    addTearDown(() {
      AuthService.currentUser = null;
      AuthService.sessionSchoolId = null;
    });

    TeacherRegistryService.instance.applyPersistedTeachers([
      AdminTeacherRecord(
        teacherId: 'TCH-9001',
        fullName: 'Ms Hana',
        assignedClass: 'Grade 3A',
        schoolId: 'FR-001',
        classAssignments: const [
          TeacherClassAssignment(
            className: 'Grade 3A',
            role: TeacherStaffRole.homeroomTeacher,
          ),
        ],
      ),
    ]);
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-2002',
        fullName: 'Other Class',
        grade: 'Grade 5',
        className: 'Grade 5B',
        schoolId: 'FR-001',
        dateOfBirth: DateTime(2015, 1, 1),
      ),
    ]);

    final data = SchoolDataService.instance;
    expect(data.teacherQrClassNames(), ['Grade 3A']);
    expect(
      data
          .getStudentQrProfilesForClasses(data.teacherQrClassNames())
          .map((profile) => profile.id),
      ['stu-1001'],
    );

    expect(
      data.recordQrScan(
        qrCode: 'STUDENT:STU-2002',
        action: QrScanAction.present,
        scannedBy: 'Ms Hana',
        allowedClassNames: data.teacherQrClassNames(),
        syncAttendance: true,
      ),
      'wrong_class',
    );
    expect(
      data.recordQrScan(
        qrCode: 'STUDENT:STU-1001',
        action: QrScanAction.present,
        scannedBy: 'Ms Hana',
        allowedClassNames: data.teacherQrClassNames(),
        syncAttendance: true,
      ),
      isNull,
    );
  });
}
