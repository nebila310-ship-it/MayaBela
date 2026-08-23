import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/hr_transport_onboarding_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'FR-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'hr',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'HR',
    );
    DriverRegistryService.instance.applyPersistedDrivers(
      const [],
      nextId: 2001,
      replace: true,
    );
    BusRegistryService.instance.applyPersistedBuses(const [], replace: true);
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-BUS1',
        fullName: 'Rider One',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 1, 1),
      ),
      AdminStudentRecord(
        studentId: 'STU-BUS2',
        fullName: 'Rider Two',
        grade: 'Grade 3',
        className: 'Grade 3A',
        schoolId: schoolId,
        dateOfBirth: DateTime(2016, 2, 2),
      ),
    ], replace: true);
    BusLiveLocationService.instance.clearPositions();
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  test('HR can register a driver, bus, and linked students', () async {
    final created = await HrTransportOnboardingService.instance.registerDriver(
      schoolId: schoolId,
      fullName: 'Abebe Driver',
      phone: '0911222333',
      busNumber: 'Bus 7',
      routeFrom: 'Bole',
      routeThrough: 'Megenagna',
      routeTo: 'School',
      plateNumber: 'AA-7788',
      email: 'abebe.driver@example.com',
    );

    expect(created.ok, isTrue);
    expect(created.driver, isNotNull);
    expect(created.driver!.busId, startsWith('BUS-'));
    expect(created.loginUsername, isNotEmpty);
    expect(created.tempPassword, isNotEmpty);
    expect(AuthService.accountExists(created.loginUsername!), isTrue);

    final linked = HrTransportOnboardingService.instance.assignStudentsToBus(
      busId: created.driver!.busId,
      studentIds: const ['STU-BUS1', 'STU-BUS2'],
    );
    expect(linked, 2);
    expect(
      StudentRegistryService.instance.lookupById('STU-BUS1')!.transportId,
      created.driver!.busId,
    );
    expect(
      StudentRegistryService.instance.lookupById('STU-BUS1')!.transportEnabled,
      isTrue,
    );
  });

  test('rejects a phone that is already registered', () async {
    final first = await HrTransportOnboardingService.instance.registerDriver(
      schoolId: schoolId,
      fullName: 'First Driver',
      phone: '0911444555',
      busNumber: 'Bus 1',
      routeFrom: 'A',
      routeThrough: 'B',
      routeTo: 'C',
      plateNumber: 'AA-1111',
    );
    expect(first.ok, isTrue);

    final again = await HrTransportOnboardingService.instance.registerDriver(
      schoolId: schoolId,
      fullName: 'Second Driver',
      phone: '0911444555',
      busNumber: 'Bus 2',
      routeFrom: 'A',
      routeThrough: 'B',
      routeTo: 'C',
      plateNumber: 'AA-2222',
    );
    expect(again.ok, isFalse);
    expect(again.errorCode, 'exists');
  });

  test('live GPS freshness is waiting until the driver phone publishes', () {
    expect(
      BusLiveLocationService.instance.freshnessFor('DRV-2001'),
      BusGpsFreshness.waiting,
    );
    BusLiveLocationService.instance.applyCloudPosition(
      BusLivePosition(
        driverId: 'DRV-2001',
        latitude: 9.01,
        longitude: 38.76,
        timestamp: DateTime.now(),
      ),
    );
    expect(
      BusLiveLocationService.instance.freshnessFor('DRV-2001'),
      BusGpsFreshness.live,
    );
    BusLiveLocationService.instance.applyCloudPosition(
      BusLivePosition(
        driverId: 'DRV-2001',
        latitude: 9.01,
        longitude: 38.76,
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
    );
    expect(
      BusLiveLocationService.instance.freshnessFor('DRV-2001'),
      BusGpsFreshness.stale,
    );
  });
}
