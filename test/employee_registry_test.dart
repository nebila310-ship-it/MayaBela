import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/employee_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EmployeeRegistryService.instance.applyPersistedEmployees(const []);
  });

  test('adds and deactivates record-only employees', () async {
    final service = EmployeeRegistryService.instance;

    final record = service.addEmployee(
      schoolId: 'TB-001',
      fullName: 'Abebe Kebede',
      jobTitle: 'Guard',
      phone: '0911000000',
      department: 'Security',
    );

    expect(record.employeeId, startsWith('EMP-'));
    expect(service.lookupById(record.employeeId)?.jobTitle, 'Guard');
    expect(
      service.employeesForSchool('TB-001').any((e) => e.employeeId == record.employeeId),
      isTrue,
    );

    expect(service.deactivateEmployee(record.employeeId), isTrue);
    expect(
      service.employeesForSchool('TB-001').any((e) => e.employeeId == record.employeeId),
      isFalse,
    );
    expect(
      service
          .employeesForSchool('TB-001', includeInactive: true)
          .any((e) => e.employeeId == record.employeeId && !e.isActive),
      isTrue,
    );
  });
}
