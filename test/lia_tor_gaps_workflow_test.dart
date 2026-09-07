import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/web_erp/config/web_erp_nav_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StudentSupportService.resetForTests();
    DosaService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'vp.care',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.vicePresident],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('Phase K: house serializes on the student registry', () {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'House Test',
      grade: 'Grade 4',
      className: 'Grade 4A',
      dateOfBirth: DateTime(2016, 1, 1),
      house: 'Blue',
    );
    expect(student.house, 'Blue');
    expect(AdminStudentRecord.fromMap(student.toMap()).house, 'Blue');
  });

  test('Phase K: admission documents can carry a file path', () {
    final doc = const AdmissionDocument(
      id: 'birth',
      label: 'Birth certificate',
      filePath: 'admission_documents/birth.pdf',
    );
    expect(AdmissionDocument.fromMap(doc.toMap()).filePath, 'admission_documents/birth.pdf');
  });

  test('Phase K: student document vault is not a clinic log', () async {
    final row = await StudentSupportService.instance.addStudentDocument(
      studentId: 'STU-1001',
      title: 'Birth certificate',
      category: 'identity',
      filePath: 'student_documents/birth.pdf',
      schoolId: 'TB-001',
    );
    expect(row.id.startsWith('SD-'), isTrue);
    expect(
      StudentSupportService.instance.documentsForStudent('STU-1001').first.title,
      'Birth certificate',
    );
  });

  test('Phase L: national offline papers are not sat in the portal', () async {
    final online = await ExamService.instance.createPaper(
      title: 'School quiz',
      className: 'Grade 4A',
      subject: 'Science',
      questionIds: const ['Q-0001'],
      schoolId: 'TB-001',
    );
    final offline = await ExamService.instance.createPaper(
      title: 'National paper',
      className: 'Grade 4A',
      subject: 'Science',
      questionIds: const ['Q-0001'],
      kind: ExamKind.national,
      sittingMode: ExamSittingMode.offline,
      schoolId: 'TB-001',
    );
    await ExamService.instance.setPaperStatus(
      online.id,
      ExamPaperStatus.published,
    );
    await ExamService.instance.setPaperStatus(
      offline.id,
      ExamPaperStatus.published,
    );
    expect(ExamPaper.fromMap(offline.toMap()).kind, ExamKind.national);
    expect(ExamPaper.fromMap(offline.toMap()).isOnlineSit, isFalse);
    expect(
      ExamService.instance.openPapersForClass('Grade 4A', schoolId: 'TB-001'),
      everyElement(predicate<ExamPaper>((p) => p.isOnlineSit)),
    );
    expect(
      () => ExamService.instance.startAttempt(
        paperId: offline.id,
        studentName: 'Sara Bekele',
      ),
      throwsStateError,
    );
  });

  test('Phase M: medication stock is unversioned clinic shelf', () async {
    final item = await StudentSupportService.instance.upsertMedicationStock(
      name: 'Paracetamol',
      unit: 'tab',
      quantityOnHand: 20,
      reorderLevel: 5,
      schoolId: 'TB-001',
    );
    expect(MedicationStockItem.fromMap(item.toMap()).needsReorder, isFalse);
    await StudentSupportService.instance.adjustMedicationStock(
      id: item.id,
      delta: -1,
      studentId: 'STU-1001',
    );
    expect(
      StudentSupportService.instance.medicationStockForSchool('TB-001').first.quantityOnHand,
      19,
    );
    expect(
      StudentSupportService.instance.healthForStudent('STU-1001').first.type,
      HealthRecordType.medication,
    );
  });

  test('Phase N: college artifacts are essays/recs/deadlines', () async {
    await StudentSupportService.instance.upsertCollegePlan(
      studentId: 'STU-1001',
      targets: 'AAU',
      schoolId: 'TB-001',
    );
    final plan = await StudentSupportService.instance.addCollegeArtifact(
      studentId: 'STU-1001',
      title: 'Personal essay',
      kind: CollegeArtifactKind.essay,
    );
    expect(plan.artifacts, hasLength(1));
    expect(
      CollegeGuidancePlan.fromMap(plan.toMap()).artifacts.first.kind,
      CollegeArtifactKind.essay,
    );
  });

  test('Phase O: leadership tasks, IEP training, and SEL scores', () async {
    final task = await DosaService.instance.addLeadershipTask(
      title: 'House assembly',
      assignee: 'DoSA',
      schoolId: 'TB-001',
    );
    expect(LeadershipTask.fromMap(task.toMap()).done, isFalse);
    await DosaService.instance.toggleLeadershipTask(task.id);
    expect(DosaService.instance.leadershipTasksForSchool('TB-001').first.done, isTrue);

    final iep = await StudentSupportService.instance.addIepPlan(
      studentId: 'STU-1001',
      goals: 'Reading',
      schoolId: 'TB-001',
    );
    final trained = await StudentSupportService.instance.addIepTraining(
      planId: iep.id,
      topic: 'Accommodations in class',
      trainer: 'SEN lead',
    );
    expect(IepPlan.fromMap(trained.toMap()).trainingSessions, hasLength(1));

    await StudentSupportService.instance.addSelObservation(
      studentId: 'STU-1001',
      domain: SelDomain.relationship,
      rating: 4,
      schoolId: 'TB-001',
    );
    expect(
      StudentSupportService.instance.selAverageForStudent('STU-1001', 'TB-001'),
      4,
    );
  });

  test('Phase P: analytics aliases to attendance, not a new BI module', () {
    expect(ModuleAccess.normalize('analytics'), 'attendance');
    expect(ModuleAccess.canView('analytics'), isTrue);
    final ids = webErpNavItemsForCurrentUser().map((e) => e.id).toSet();
    expect(ids, contains('analytics'));
  });

  test('Phase Q collections stay on the existing care/DoSA sync lanes', () {
    expect(AppCollections.studentDocuments, 'student_documents');
    expect(AppCollections.medicationStock, 'medication_stock');
    expect(AppCollections.selObservations, 'sel_observations');
    expect(AppCollections.leadershipTasks, 'leadership_tasks');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'student_documents',
        'medication_stock',
        'sel_observations',
        'leadership_tasks',
      ]),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['student_documents', 'medication_stock']),
    );
    AuthService.currentUser = RegisteredUser(
      username: 'parent.g',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      contains('student_documents'),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('medication_stock')),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('leadership_tasks')),
    );
  });
}
