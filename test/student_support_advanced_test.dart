import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_support_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.care',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('health tracks disposition, follow-up, and parent contact', () async {
    final visit = await StudentSupportService.instance.addHealthRecord(
      studentId: 'STU-1001',
      type: HealthRecordType.clinicVisit,
      title: 'Migraine',
      details: 'Dark room + water',
      disposition: 'sendHome',
      followUpAt: DateTime.utc(2026, 9, 13),
      vitalNotes: 'Temp 37.8',
      parentContactMethod: 'phone',
      schoolId: 'TB-001',
    );
    final restored = HealthRecord.fromMap(visit.toMap());
    expect(restored.disposition, 'sendHome');
    expect(restored.vitalNotes, 'Temp 37.8');
    expect(restored.parentContactMethod, 'phone');
    expect(
      StudentSupportService.instance
          .healthFollowUpsDue(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          )
          .single
          .title,
      'Migraine',
    );
    expect(
      StudentSupportService.instance.healthReportRows('TB-001').first,
      containsAll(['Disposition', 'Follow-up', 'Parent contact']),
    );
  });

  test('MAR stock tracks controlled drugs and a witness on dispense', () async {
    final stock = await StudentSupportService.instance.upsertMedicationStock(
      name: 'Methylphenidate',
      unit: 'tab',
      quantityOnHand: 8,
      controlledDrug: true,
      route: 'oral',
      parentConsentOnFile: true,
      prescriber: 'Dr. Bekele',
      schoolId: 'TB-001',
    );
    expect(MedicationStockItem.fromMap(stock.toMap()).controlledDrug, isTrue);
    expect(
      StudentSupportService.instance.controlledMedicationStock('TB-001'),
      hasLength(1),
    );

    await StudentSupportService.instance.adjustMedicationStock(
      id: stock.id,
      delta: -1,
      studentId: 'STU-1001',
      reason: 'dispense',
      note: '10mg 08:00',
      witnessedBy: 'sister.hana',
    );
    final movement = StudentSupportService.instance
        .medicationStockForSchool('TB-001')
        .first
        .movements
        .last;
    expect(movement.witnessedBy, 'sister.hana');
    expect(movement.reason, 'dispense');
  });

  test('vault review dates stay on student_documents and hide leadership files',
      () async {
    await StudentSupportService.instance.addStudentDocument(
      studentId: 'STU-1001',
      title: 'EP report 2026',
      category: 'psychoEd',
      confidentiality: 'restricted',
      source: 'External EP',
      reviewAt: DateTime.utc(2026, 9, 20),
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.addStudentDocument(
      studentId: 'STU-1001',
      title: 'Legal brief',
      category: 'legal',
      confidentiality: 'leadership',
      schoolId: 'TB-001',
    );
    expect(
      StudentSupportService.instance
          .vaultReviewsDue(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 11),
          )
          .single
          .title,
      'EP report 2026',
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    final visible =
        StudentSupportService.instance.documentsForSchool('TB-001');
    expect(visible.map((row) => row.title), contains('EP report 2026'));
    expect(visible.map((row) => row.title), isNot(contains('Legal brief')));
  });

  test('counseling risk-watch does not open a safeguarding case', () async {
    final session = await StudentSupportService.instance.addCounselingRecord(
      studentId: 'STU-1001',
      kind: CounselingKind.session,
      title: 'Anxiety check-in',
      parentSummary: 'Discussed exam stress',
      staffNotes: 'Private clinical note',
      format: 'individual',
      durationMinutes: 40,
      followUpAt: DateTime.utc(2026, 9, 18),
      riskWatch: 'monitor',
      schoolId: 'TB-001',
    );
    expect(CounselingRecord.fromMap(session.toMap()).riskWatch, 'monitor');
    expect(
      StudentSupportService.instance
          .counselingFollowUpsDue(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          ),
      hasLength(1),
    );
    expect(
      StudentSupportService.instance.safeguardingForSchool('TB-001'),
      isEmpty,
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    final public =
        StudentSupportService.instance.counselingForSchool('TB-001').single;
    expect(public.parentSummary, 'Discussed exam stress');
    expect(public.staffNotes, isEmpty);
    expect(public.riskWatch, 'none');
    expect(public.format, 'individual');
  });

  test('IEP tracks MTSS tier and exam access arrangements', () async {
    final plan = await StudentSupportService.instance.addIepPlan(
      studentId: 'STU-1001',
      goals: 'Read 90 wpm by Term 2',
      accommodations: 'Chunked instructions',
      mtssTier: 3,
      accessArrangements: const ['extraTime', 'separateRoom'],
      reviewCycle: 'termly',
      externalReportRef: 'EP-2026-14',
      nextReviewAt: DateTime.utc(2026, 12, 1),
      schoolId: 'TB-001',
    );
    expect(IepPlan.fromMap(plan.toMap()).mtssTier, 3);
    await StudentSupportService.instance.updateIepAccess(
      id: plan.id,
      accessArrangements: const ['extraTime', 'scribe'],
      mtssTier: 2,
    );
    final updated =
        StudentSupportService.instance.iepForSchool('TB-001').single;
    expect(updated.mtssTier, 2);
    expect(updated.accessArrangements, containsAll(['extraTime', 'scribe']));
    expect(updated.externalReportRef, 'EP-2026-14');
  });

  test('college plan tracks UCAS/Common App and testing', () async {
    final plan = await StudentSupportService.instance.upsertCollegePlan(
      studentId: 'STU-1001',
      stage: CollegeStage.applying,
      targets: 'UCL, Toronto',
      applicationSystem: 'both',
      testingPlan: 'IELTS Oct · SAT Nov',
      counselorName: 'Ms. Lemma',
      destinationCountry: 'UK / Canada',
      schoolId: 'TB-001',
    );
    final restored = CollegeGuidancePlan.fromMap(plan.toMap());
    expect(restored.applicationSystem, 'both');
    expect(restored.testingPlan, contains('IELTS'));
    expect(restored.counselorName, 'Ms. Lemma');
  });

  test('support requests track priority, assignee, and overdue', () async {
    final request = await StudentSupportService.instance.submitSupportRequest(
      studentId: 'STU-1001',
      kind: SupportRequestKind.counselingAppointment,
      body: 'Need a same-week slot',
      priority: 'urgent',
      dueAt: DateTime.utc(2026, 9, 10),
      schoolId: 'TB-001',
    );
    await StudentSupportService.instance.assignSupportRequest(
      id: request.id,
      assignedTo: 'counselor.lia',
      lastActionNote: 'Offered Thursday 14:00',
    );
    final row =
        StudentSupportService.instance.requestsForSchool('TB-001').single;
    expect(row.priority, 'urgent');
    expect(row.assignedTo, 'counselor.lia');
    expect(row.lastActionNote, contains('Thursday'));
    expect(
      StudentSupportService.instance
          .overdueSupportRequests(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          ),
      hasLength(1),
    );
  });

  test('safeguarding chronology stays off the parent tile', () async {
    final file = await StudentSupportService.instance.openSafeguardingCase(
      studentId: 'STU-1001',
      title: 'Welfare concern',
      details: 'Restricted narrative',
      category: 'emotional',
      dslName: 'Ms. Hailu',
      agencyReferred: '',
      nextReviewAt: DateTime.utc(2026, 9, 18),
      schoolId: 'TB-001',
    );
    expect(file.chronology, isNotEmpty);
    await StudentSupportService.instance.addSafeguardingChronology(
      id: file.id,
      note: 'Spoke with class teacher. No disclosure in parent chat.',
      agencyReferred: 'City child-protection',
      nextReviewAt: DateTime.utc(2026, 9, 20),
    );
    final updated =
        StudentSupportService.instance.safeguardingForSchool('TB-001').single;
    expect(updated.category, 'emotional');
    expect(updated.dslName, 'Ms. Hailu');
    expect(updated.agencyReferred, 'City child-protection');
    expect(updated.chronology, hasLength(2));
    expect(
      StudentSupportService.instance
          .safeguardingReviewsDue(
            schoolId: 'TB-001',
            now: DateTime.utc(2026, 9, 12),
          ),
      hasLength(1),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
    );
    expect(
      StudentSupportService.instance.safeguardingForSchool('TB-001'),
      isEmpty,
    );
  });

  test('playbook covers all eight student-support desks', () {
    for (final desk in const [
      'health',
      'meds',
      'vault',
      'counseling',
      'iep',
      'college',
      'requests',
      'safeguarding',
    ]) {
      expect(StudentSupportPlaybook.banners[desk], isNotEmpty);
    }
    expect(
      StudentSupportPlaybook.label(
        StudentSupportPlaybook.dispositions,
        'returnToClass',
      ),
      'Return to class',
    );
  });
}
