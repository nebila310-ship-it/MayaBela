import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_audit_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signInAsTransportAdmin() {
    AuthService.currentUser = RegisteredUser(
      username: 'transport_admin',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      fullName: 'Transport Admin',
      staffRoles: [StaffRoles.transportAdmin],
    );
  }

  void signInAsOwner() {
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'School Owner',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BusRegistryService.instance.applyPersistedBuses(const [], replace: true);
    SchoolAuditLogService.instance
        .applyPersistedEntries(const [], replace: true);
    DriverRegistryService.instance.applyPersistedDrivers(
      const [],
      nextId: 1001,
      replace: true,
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  group('Bus registry (Phase E)', () {
    test('transport admin can create bus with plate/capacity/route', () async {
      signInAsTransportAdmin();
      final bus = await BusRegistryService.instance.addBus(
        busNumber: '12',
        plateNumber: 'AA-12345',
        routeName: 'Bole Route',
        capacity: 45,
      );
      expect(bus, isNotNull);
      expect(bus!.busId, startsWith('BUS-'));
      expect(bus.busNumber, 'Bus 12');
      expect(bus.plateNumber, 'AA-12345');
      expect(bus.capacity, 45);
      expect(bus.routeName, 'Bole Route');
      expect(
        BusRegistryService.instance.busesForSchool(schoolId),
        hasLength(1),
      );
    });

    test('assigning a driver syncs denormalized driver bus fields', () async {
      signInAsOwner();
      final driver = DriverRegistryService.instance.addDriver(
        schoolId: schoolId,
        fullName: 'Driver One',
        busNumber: 'Bus 1',
        routeName: 'Old Route',
        plateNumber: 'OLD-1',
        phone: '0911000000',
        loginUsername: 'drv1',
        initialPassword: 'pass',
      );
      await Future<void>.delayed(Duration.zero);

      final bus = await BusRegistryService.instance.addBus(
        busNumber: 'Bus 9',
        plateNumber: 'NEW-9',
        routeName: 'New Route',
        capacity: 40,
      );
      expect(bus, isNotNull);

      final ok = await BusRegistryService.instance.assignDriver(
        busId: bus!.busId,
        driverId: driver.driverId,
      );
      expect(ok, isTrue);

      final refreshed =
          DriverRegistryService.instance.lookupById(driver.driverId);
      expect(refreshed?.busId, bus.busId);
      expect(refreshed?.plateNumber, 'NEW-9');
      expect(refreshed?.routeName, 'New Route');
    });

    test('seedFromDriversIfEmpty backfills buses from drivers', () {
      AuthService.currentUser = null;
      DriverRegistryService.instance.applyPersistedDrivers(
        [
          AdminDriverRecord(
            driverId: 'DRV-1001',
            busId: 'BUS-1001',
            fullName: 'Seed Driver',
            busNumber: 'Bus 1',
            routeName: 'Seed Route',
            plateNumber: 'SEED-1',
            schoolId: schoolId,
            phone: '0911000001',
            loginUsername: 'seeddrv',
          ),
        ],
        nextId: 1002,
        replace: true,
      );
      BusRegistryService.instance.seedFromDriversIfEmpty();
      final buses = BusRegistryService.instance.busesForSchool(schoolId);
      expect(buses, hasLength(1));
      expect(buses.first.busId, 'BUS-1001');
      expect(buses.first.assignedDriverId, 'DRV-1001');
    });
  });

  group('School audit log (Phase F)', () {
    test('bus mutations write audit entries with before/after', () async {
      signInAsTransportAdmin();
      final bus = await BusRegistryService.instance.addBus(
        busNumber: 'Bus 3',
        plateNumber: 'PL-3',
        routeName: 'R3',
      );
      expect(bus, isNotNull);

      await BusRegistryService.instance.updateBus(
        bus!.copyWith(routeName: 'R3 Updated', capacity: 50),
      );

      final entries = SchoolAuditLogService.instance.filtered(
        schoolId: schoolId,
        entityType: 'bus',
      );
      expect(entries.length, greaterThanOrEqualTo(2));
      expect(entries.any((e) => e.action == 'bus_created'), isTrue);
      final updated = entries.firstWhere((e) => e.action == 'bus_updated');
      expect(updated.before?['routeName'], 'R3');
      expect(updated.after?['routeName'], 'R3 Updated');
      expect(updated.actorId, 'transport_admin');
    });

    test('manual school audit log stores actor and snapshots', () async {
      signInAsOwner();
      await SchoolAuditLogService.instance.log(
        action: 'test_action',
        entityType: 'staff',
        entityId: 'user-1',
        detail: 'unit test',
        before: {'a': 1},
        after: {'a': 2},
      );
      final recent =
          SchoolAuditLogService.instance.recentForSchool(schoolId, limit: 5);
      expect(recent, isNotEmpty);
      expect(recent.first.action, 'test_action');
      expect(recent.first.before?['a'], 1);
      expect(recent.first.after?['a'], 2);
      expect(recent.first.actorName, 'School Owner');
    });
  });
}
