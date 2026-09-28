import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_report_export_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AdmissionService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'reg.lia',
      password: 'secret',
      roleKey: AuthService.roleTeacher,
      schoolId: 'LIA-001',
      fullName: 'Registrar',
      staffRoles: const [StaffRoles.registrar],
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
    AdmissionService.resetForTests();
  });

  test('application serializes round-trip', () {
    final now = DateTime.now().toUtc();
    final original = AdmissionApplication(
      id: 'APP-0001',
      schoolId: 'LIA-001',
      fullName: 'Abebe Kebede',
      stage: AdmissionStage.application,
      source: AdmissionSource.online,
      gradeApplying: 'Grade 5',
      guardianName: 'Almaz',
      guardianPhone: '0911000000',
      previousSchool: 'Lideta Primary',
      lastGradeCompleted: 'Grade 4',
      previousAverage: 86,
      documents: AdmissionApplication.defaultDocuments(),
      createdAt: now,
      updatedAt: now,
    );
    final copy = AdmissionApplication.fromMap(original.toMap());
    expect(copy.id, 'APP-0001');
    expect(copy.stage, AdmissionStage.application);
    expect(copy.source, AdmissionSource.online);
    expect(copy.documents, hasLength(4));
    expect(copy.documentsComplete, isFalse);
    expect(copy.previousSchool, 'Lideta Primary');
    expect(copy.lastGradeCompleted, 'Grade 4');
    expect(copy.previousAverage, 86);
  });

  test('pipeline inquiry → documents → offer → enroll creates a student',
      () async {
    final created = await AdmissionService.instance.createInquiry(
      fullName: 'Marta Hailu',
      gradeApplying: 'Grade 4',
      guardianName: 'Hailu',
      guardianPhone: '0911222333',
      source: AdmissionSource.walkIn,
      schoolId: 'LIA-001',
    );
    expect(created.stage, AdmissionStage.inquiry);
    expect(created.id, matches(RegExp(r'^APP-\d{4}$')));

    await AdmissionService.instance.moveTo(
      created.id,
      AdmissionStage.application,
    );
    for (final doc in created.documents) {
      await AdmissionService.instance.setDocument(
        created.id,
        doc.id,
        submitted: true,
        verified: true,
      );
    }
    var current = AdmissionService.instance.byId(created.id)!;
    expect(current.documentsComplete, isTrue);
    expect(current.stage, AdmissionStage.documentsVerified);

    await AdmissionService.instance.recordExam(
      created.id,
      examDate: DateTime(2026, 9, 1),
      score: 82,
    );
    current = AdmissionService.instance.byId(created.id)!;
    expect(current.stage, AdmissionStage.examScored);
    expect(current.examScore, 82);

    await AdmissionService.instance.placeOnWaitlist(created.id);
    current = AdmissionService.instance.byId(created.id)!;
    expect(current.stage, AdmissionStage.waitlist);
    expect(current.waitlistRank, 1);

    await AdmissionService.instance.moveTo(created.id, AdmissionStage.offered);
    await AdmissionService.instance.moveTo(created.id, AdmissionStage.accepted);
    final student = await AdmissionService.instance.enroll(
      created.id,
      className: 'Grade 4A',
      grade: 'Grade 4',
    );
    expect(student, isNotNull);
    expect(student!.studentId, matches(RegExp(r'^STU-\d{4}$')));
    expect(student.fullName, 'Marta Hailu');
    current = AdmissionService.instance.byId(created.id)!;
    expect(current.stage, AdmissionStage.enrolled);
    expect(current.enrolledStudentId, student.studentId);
    expect(
      StudentRegistryService.instance.lookupById(student.studentId)?.fullName,
      'Marta Hailu',
    );
    expect(
      StudentRegistryService.instance
          .studentsForClass('Grade 4A', schoolId: 'LIA-001')
          .map((s) => s.studentId),
      contains(student.studentId),
    );
    expect(current.stageLabel, 'Enrolled');
  });

  test('enroll from an offer puts the student on the class list', () async {
    final created = await AdmissionService.instance.createInquiry(
      fullName: 'Yonas Lemma',
      gradeApplying: 'Grade 5',
      schoolId: 'LIA-001',
      stage: AdmissionStage.offered,
    );
    final student = await AdmissionService.instance.enroll(
      created.id,
      className: 'Grade 5B',
      grade: 'Grade 5',
    );
    expect(student, isNotNull);
    expect(
      AdmissionService.instance.byId(created.id)!.stage,
      AdmissionStage.enrolled,
    );
    expect(
      StudentRegistryService.instance
          .studentsForClass('Grade 5B', schoolId: 'LIA-001')
          .map((s) => s.fullName),
      contains('Yonas Lemma'),
    );
  });

  test('cannot skip document verification', () async {
    final created = await AdmissionService.instance.createInquiry(
      fullName: 'Skip Docs',
      schoolId: 'LIA-001',
      stage: AdmissionStage.documentsPending,
    );
    final moved = await AdmissionService.instance.moveTo(
      created.id,
      AdmissionStage.documentsVerified,
    );
    expect(moved?.stage, AdmissionStage.documentsPending);
  });

  test('stale illegal transition is ignored', () async {
    final created = await AdmissionService.instance.createInquiry(
      fullName: 'Early Enroll',
      schoolId: 'LIA-001',
    );
    final student = await AdmissionService.instance.enroll(
      created.id,
      className: 'Grade 1A',
    );
    expect(student, isNull);
    expect(
      AdmissionService.instance.byId(created.id)!.stage,
      AdmissionStage.inquiry,
    );
  });

  test('funnel analytics count waitlist and enrolled', () async {
    await AdmissionService.instance.createInquiry(
      fullName: 'One',
      schoolId: 'LIA-001',
      stage: AdmissionStage.waitlist,
    );
    await AdmissionService.instance.createInquiry(
      fullName: 'Two',
      schoolId: 'LIA-001',
      stage: AdmissionStage.offered,
    );
    final counts = AdmissionService.instance.funnelCounts('LIA-001');
    expect(counts[AdmissionStage.waitlist], 1);
    expect(counts[AdmissionStage.offered], 1);
    expect(AdmissionService.instance.openCount('LIA-001'), 2);
  });

  test('alumni are graduated registry students', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'LIA-001',
      fullName: 'Alumni Kid',
      grade: 'Grade 12',
      className: 'Grade 12A',
      dateOfBirth: DateTime(2008, 1, 1),
    );
    StudentRegistryService.instance.setLifecycleStatus(
      student.studentId,
      StudentLifecycleStatus.graduated,
    );
    final alumni = StudentRegistryService.instance.registrySnapshot().where(
          (s) =>
              s.lifecycleStatus == StudentLifecycleStatus.graduated &&
              s.schoolId.toUpperCase() == 'LIA-001',
        );
    expect(alumni.map((s) => s.studentId), contains(student.studentId));
  });

  test('declining an offer promotes the next waitlisted applicant', () async {
    final offered = await AdmissionService.instance.createInquiry(
      fullName: 'First Seat',
      gradeApplying: 'Grade 5',
      schoolId: 'LIA-001',
      stage: AdmissionStage.offered,
    );
    await AdmissionService.instance.update(
      offered.id,
      (a) => a.copyWith(stage: AdmissionStage.offered),
    );
    final waiting = await AdmissionService.instance.createInquiry(
      fullName: 'Next Seat',
      gradeApplying: 'Grade 5',
      schoolId: 'LIA-001',
    );
    await AdmissionService.instance.recordExam(
      waiting.id,
      examDate: DateTime(2026, 9, 1),
      score: 91,
    );
    await AdmissionService.instance.placeOnWaitlist(waiting.id);
    expect(
      AdmissionService.instance.byId(waiting.id)!.stage,
      AdmissionStage.waitlist,
    );

    await AdmissionService.instance.moveTo(
      offered.id,
      AdmissionStage.declined,
      reason: 'Family declined',
    );
    expect(
      AdmissionService.instance.byId(waiting.id)!.stage,
      AdmissionStage.offered,
    );
  });

  test('expired offers decline and free the waitlist seat', () async {
    final stale = await AdmissionService.instance.createInquiry(
      fullName: 'Expired Offer',
      gradeApplying: 'Grade 6',
      schoolId: 'LIA-001',
    );
    await AdmissionService.instance.update(
      stale.id,
      (a) => a.copyWith(
        stage: AdmissionStage.offered,
        offerExpiresAt: DateTime(2026, 1, 1),
      ),
    );
    final waiting = await AdmissionService.instance.createInquiry(
      fullName: 'Waiter',
      gradeApplying: 'Grade 6',
      schoolId: 'LIA-001',
    );
    await AdmissionService.instance.placeOnWaitlist(waiting.id);

    final expired = await AdmissionService.instance.expireStaleOffers(
      schoolId: 'LIA-001',
      now: DateTime(2026, 1, 15),
    );
    expect(expired, 1);
    expect(
      AdmissionService.instance.byId(stale.id)!.stage,
      AdmissionStage.declined,
    );
    expect(
      AdmissionService.instance.byId(waiting.id)!.stage,
      AdmissionStage.offered,
    );
  });

  test('analytics and admissions report include the funnel', () async {
    await AdmissionService.instance.createInquiry(
      fullName: 'Closed Enroll',
      schoolId: 'LIA-001',
      stage: AdmissionStage.enrolled,
    );
    await AdmissionService.instance.createInquiry(
      fullName: 'Closed Reject',
      schoolId: 'LIA-001',
      stage: AdmissionStage.rejected,
    );
    final stats = AdmissionService.instance.analytics('LIA-001');
    expect(stats.funnel[AdmissionStage.enrolled], 1);
    expect(stats.funnel[AdmissionStage.rejected], 1);
    expect(stats.conversionPercent, 50);
    expect(stats.sources[AdmissionSource.staff], 2);

    AuthService.currentUser = RegisteredUser(
      username: 'reg.lia',
      password: 'secret',
      roleKey: AuthService.roleTeacher,
      schoolId: 'LIA-001',
      staffRoles: const [StaffRoles.registrar],
    );
    final bytes = await SchoolReportExportService.instance
        .buildPdfBytes(SchoolReportKind.admissions);
    expect(bytes, isNotEmpty);
  });

  test('registrar sees admissions module; collection is on the sync engine', () {
    expect(ModuleAccess.canView('admissions'), isTrue);
    expect(ModuleAccess.canManage('admissions'), isTrue);
    expect(ModuleAccess.canView('alumni'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('admissions'));
    expect(ids, contains('alumni'));
    expect(
      CloudSyncEngine.standardPriority,
      contains(AppCollections.admissionApplications),
    );
  });
}
