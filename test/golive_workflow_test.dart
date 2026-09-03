import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/student_excel_import.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/totp.dart';
import 'package:mayabela/web_erp/pages/web_go_live_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoliveService.resetForTests();
    ExamService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'owner.j',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
      staffRoles: const [StaffRoles.principal],
    );
  });

  tearDown(() => AuthService.currentUser = null);

  test('TOTP verifies in the 30s window and Admin is not enrolled by default', () {
    final secret = Totp.generateSecret();
    final code = Totp.generateCode(secret);
    expect(Totp.verify(secret, code), isTrue);
    expect(Totp.verify(secret, '000000'), isFalse);
    expect(GoliveService.instance.isEnabledFor('Admin'), isFalse);
    expect(GoliveService.instance.isEnabledFor('owner.j'), isFalse);
  });

  test('consent serializes and recovery codes hash', () {
    final now = DateTime.utc(2026, 9, 3);
    final consent = PrivacyConsent(
      id: 'CON-0001',
      schoolId: 'TB-001',
      subjectName: 'Parent A',
      purpose: ConsentPurpose.photos,
      state: ConsentState.granted,
      createdAt: now,
      updatedAt: now,
      studentId: 'STU-1001',
      authorUsername: 'parent.a',
    );
    expect(PrivacyConsent.fromMap(consent.toMap()).purpose, ConsentPurpose.photos);
    final codes = Totp.generateRecoveryCodes(count: 2);
    expect(codes, hasLength(2));
    expect(Totp.hashRecovery(codes.first), isNot(codes.first));
  });

  test('parents never see another family data-rights request', () async {
    AuthService.currentUser = RegisteredUser(
      username: 'parent.a',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1001'],
      linkedStudentId: 'STU-1001',
    );
    await GoliveService.instance.fileDataRightsRequest(
      kind: DataRightsKind.access,
      studentId: 'STU-1001',
      details: 'Copy for Sara',
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.b',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
      linkedStudentIds: const ['STU-1002'],
      linkedStudentId: 'STU-1002',
    );
    final visible = GoliveService.instance.rightsForSchool('TB-001');
    expect(visible, isEmpty);

    await GoliveService.instance.fileDataRightsRequest(
      kind: DataRightsKind.erasure,
      studentId: 'STU-1002',
      details: 'Redact phones',
    );
    expect(GoliveService.instance.rightsForSchool('TB-001'), hasLength(1));
    expect(GoliveService.instance.rightsForSchool('TB-001').first.studentId, 'STU-1002');
  });

  test('Excel parse imports via addStudent and does not write exams', () async {
    const csv = 'Full Name,Grade,Class,Date of Birth\n'
        'Imported Kid,5,5A,2015-03-04\n';
    final rows = StudentExcelImport.parseCsv(csv);
    expect(rows, hasLength(1));
    expect(rows.first.fullName, 'Imported Kid');

    final beforeExams = ExamService.instance.papersForSchool('TB-001').length;
    final result = await GoliveService.instance.importStudentRows(rows);
    expect(result.createdIds, hasLength(1));
    expect(result.createdIds.first, startsWith('STU-'));
    final created =
        StudentRegistryService.instance.lookupAnyById(result.createdIds.first);
    expect(created?.fullName, 'Imported Kid');
    expect(created?.className, '5A');
    expect(ExamService.instance.papersForSchool('TB-001'), hasLength(beforeExams));

    final again = await GoliveService.instance.importStudentRows(rows);
    expect(again.createdIds, isEmpty);
    expect(again.skipped, isNotEmpty);
  });

  test('erasure redacts personal fields and keeps the student id', () async {
    final student = StudentRegistryService.instance.addStudent(
      schoolId: 'TB-001',
      fullName: 'Erase Me',
      grade: '5',
      className: '5A',
      dateOfBirth: DateTime(2014, 1, 1),
      fatherPhone: '0911222333',
    );
    await GoliveService.instance.fileDataRightsRequest(
      kind: DataRightsKind.erasure,
      studentId: student.studentId,
    );
    final req = GoliveService.instance.rightsForSchool().first;
    await GoliveService.instance.reviewDataRights(
      req.id,
      DataRightsStatus.redacted,
    );
    final after =
        StudentRegistryService.instance.lookupAnyById(student.studentId);
    expect(after?.studentId, student.studentId);
    expect(after?.grade, '5');
    expect(after?.fullName, 'Redacted ${student.studentId}');
    expect(after?.fatherPhone, isNull);
    final export = GoliveService.instance.subjectAccessExport(student.studentId);
    expect(export['excluded'], contains('safeguarding / child-protection files'));
    expect(export.containsKey('staffNotes'), isFalse);
  });

  test('go-live aliases to the desk and syncs on the standard lane', () {
    expect(ModuleAccess.canView('go_live'), isTrue);
    expect(ModuleAccess.canManage('compliance'), isTrue);
    expect(ModuleAccess.normalize('privacy'), 'go_live');
    expect(ModuleAccess.normalize('backups'), 'go_live');
    expect(ModuleAccess.normalize('training_manuals'), 'go_live');
    expect(AppCollections.mfaEnrollments, 'mfa_enrollments');
    expect(
      CloudSyncEngine.standardPriority,
      containsAll([
        'mfa_enrollments',
        'privacy_consents',
        'data_rights_requests',
        'school_backups',
      ]),
    );

    AuthService.currentUser = RegisteredUser(
      username: 'parent.j',
      password: 'x',
      roleKey: AuthService.roleParent,
      schoolId: 'TB-001',
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      containsAll(['privacy_consents', 'data_rights_requests']),
    );
    expect(
      CloudSyncEngine.collectionsForCurrentRole(),
      isNot(contains('school_backups')),
    );
  });

  testWidgets('Go-live desk shows Phase J tabs', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebGoLivePage()),
      ),
    );
    await tester.pump();
    expect(find.text('Go-live & compliance'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
  });
}
