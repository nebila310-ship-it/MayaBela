import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/driver_persistence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/phone_utils.dart';

class HrDriverOnboardingResult {
  const HrDriverOnboardingResult({
    required this.ok,
    this.driver,
    this.tempPassword,
    this.loginUsername,
    this.errorCode,
  });

  final bool ok;
  final AdminDriverRecord? driver;
  final String? tempPassword;
  final String? loginUsername;
  final String? errorCode;
}

/// HR / Transport Head: register a driver login, create their bus, and
/// optionally attach students (transportId = BUS-*).
class HrTransportOnboardingService {
  HrTransportOnboardingService._();
  static final instance = HrTransportOnboardingService._();

  Future<HrDriverOnboardingResult> registerDriver({
    required String schoolId,
    required String fullName,
    required String phone,
    required String busNumber,
    required String routeFrom,
    required String routeThrough,
    required String routeTo,
    required String plateNumber,
    String? email,
  }) async {
    final sid = schoolId.trim().toUpperCase();
    if (sid.isEmpty) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'no_school');
    }
    if (fullName.trim().isEmpty) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'name');
    }
    if (!PhoneUtils.isValidLoginPhone(phone)) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'invalid_phone');
    }
    if (busNumber.trim().isEmpty) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'bus_number');
    }
    if (routeFrom.trim().isEmpty ||
        routeThrough.trim().isEmpty ||
        routeTo.trim().isEmpty) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'route');
    }
    if (plateNumber.trim().isEmpty) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'plate');
    }

    final loginKey = PhoneUtils.loginKey(phone);
    if (AuthService.accountExists(loginKey)) {
      return const HrDriverOnboardingResult(ok: false, errorCode: 'exists');
    }

    final tempPassword = AuthService.generateTempPassword();
    final routeName = DriverRegistryService.formatRoute(
      routeFrom,
      routeTo,
      through: routeThrough,
    );

    var driver = DriverRegistryService.instance.addDriver(
      schoolId: sid,
      fullName: fullName,
      phone: phone,
      email: email,
      busNumber: busNumber,
      routeName: routeName,
      plateNumber: plateNumber,
      loginUsername: loginKey,
      initialPassword: tempPassword,
    );
    final createdId = driver.driverId;

    try {
      final authError = AuthService.registerDriverAccount(
        fullName: fullName,
        schoolId: sid,
        phone: phone,
        email: email?.trim().isEmpty == true ? null : email?.trim(),
        linkedDriverId: driver.driverId,
        password: tempPassword,
      );
      if (authError != null) {
        DriverRegistryService.instance.removeDriver(createdId);
        return HrDriverOnboardingResult(ok: false, errorCode: authError);
      }

      DriverRegistryService.instance.saveCredentials(
        driverId: driver.driverId,
        initialPassword: tempPassword,
        loginUsername: loginKey,
        persist: false,
      );
      driver = DriverRegistryService.instance.lookupById(driver.driverId)!;
      AuthService.syncDriverAuthProfile(driver);
      await DriverPersistenceService.instance.saveRegistryFromService();

      return HrDriverOnboardingResult(
        ok: true,
        driver: driver,
        tempPassword: tempPassword,
        loginUsername: loginKey,
      );
    } catch (_) {
      DriverRegistryService.instance.removeDriver(createdId);
      await AuthService.revokeRegisteredAccount(loginKey);
      return const HrDriverOnboardingResult(ok: false, errorCode: 'failed');
    }
  }

  int assignStudentsToBus({
    required String busId,
    required Iterable<String> studentIds,
  }) {
    final link = busId.trim().toUpperCase();
    if (link.isEmpty) return 0;
    var count = 0;
    for (final raw in studentIds) {
      final student = StudentRegistryService.instance.lookupById(raw);
      if (student == null) continue;
      StudentRegistryService.instance.updateStudent(
        student.copyWith(
          transportEnabled: true,
          transportId: link,
        ),
      );
      count++;
    }
    return count;
  }
}
