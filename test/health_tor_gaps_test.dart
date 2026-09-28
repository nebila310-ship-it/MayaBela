import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'nurse.clinic',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      fullName: 'Sister Hana',
      staffRoles: const [StaffRoles.studentAffairs, StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('clinic visit records time, staff, and daily log', () async {
    final day = DateTime.utc(2026, 9, 11);
    final visit = await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.clinicVisit,
      title: 'Headache',
      details: 'Rest + water',
      occurredAt: day,
      schoolId: 'TB-001',
    );
    expect(visit.recordedAt, day);
    expect(visit.createdBy, 'nurse.clinic');
    expect(visit.severity, 'routine');

    final log = StudentSupportService.instance.clinicLogForDate(day, 'TB-001');
    expect(log, hasLength(1));
    expect(log.first.title, 'Headache');
    expect(
      StudentSupportService.instance.clinicSummaryForDate(day, 'TB-001').visits,
      1,
    );
  });

  test('vaccination tracks dose and due date on the same health store', () async {
    final shot = await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.vaccination,
      title: 'MMR',
      vaccineName: 'MMR',
      doseNumber: 2,
      nextDueAt: DateTime.utc(2026, 10, 1),
      occurredAt: DateTime.utc(2026, 9, 11),
      schoolId: 'TB-001',
    );
    expect(HealthRecord.fromMap(shot.toMap()).doseNumber, 2);
    expect(
      StudentSupportService.instance
          .vaccinesDueSoon(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 20),
          )
          .single
          .vaccineName,
      'MMR',
    );
  });

  test('emergency alert notifies the linked parent', () async {
    await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.emergencyAlert,
      title: 'Asthma attack',
      details: 'Used inhaler, observing',
      schoolId: 'TB-001',
    );
    final row = StudentSupportService.instance.healthForStudent('STU-1001').first;
    expect(row.isUrgent, isTrue);
    expect(row.parentNotifiedAt, isNotNull);
    expect(
      NotificationService.instance.itemsForTests().any(
        (n) =>
            n.recipientRole == AuthService.roleParent &&
            n.targetStudentId == 'STU-1001' &&
            n.title.contains('Emergency'),
      ),
      isTrue,
    );
  });

  test('dispense writes a stock ledger and a medication health row', () async {
    final stock = await StudentSupportService.instance.upsertMedicationStock(
      name: 'Paracetamol',
      unit: 'tab',
      quantityOnHand: 10,
      batchNumber: 'B-22',
      schoolId: 'TB-001',
    );
    expect(stock.movements, hasLength(1));
    expect(stock.movements.first.reason, 'receive');

    await StudentSupportService.instance.adjustMedicationStock(
      id: stock.id,
      delta: -2,
      studentId: 'STU-1001',
      note: '500mg after lunch',
      reason: 'dispense',
    );
    final updated = StudentSupportService.instance
        .medicationStockForSchool('TB-001')
        .first;
    expect(updated.quantityOnHand, 8);
    expect(updated.movements.last.reason, 'dispense');
    expect(updated.movements.last.studentId, 'STU-1001');

    final given = StudentSupportService.instance
        .healthForStudent('STU-1001')
        .firstWhere((r) => r.type == HealthRecordType.medication);
    expect(given.medicationStockItemId, stock.id);
    expect(given.quantity, 2);
    expect(given.details, contains('batch B-22'));
  });

  test('health report rows export the live clinic register', () async {
    await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.clinicVisit,
      title: 'Fever',
      schoolId: 'TB-001',
    );
    final rows = StudentSupportService.instance.healthReportRows('TB-001');
    expect(rows.first, contains('Type'));
    expect(rows.any((r) => r.contains('Fever')), isTrue);
    expect(SchoolReportKind.health.name, 'health');
  });

  test('health stays on the existing student-support desk', () {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.health',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
    expect(ModuleAccess.normalize('health'), 'student_affairs');
    expect(ModuleAccess.canView('student_affairs'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('student_support'));
  });
}
