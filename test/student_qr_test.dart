import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/student_registry_service.dart';
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
}
