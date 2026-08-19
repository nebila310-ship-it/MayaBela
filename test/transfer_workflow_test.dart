import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/class_structure_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signIn(String username, String roleKey, List<String> staffRoles) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: username,
      staffRoles: staffRoles,
    );
  }

  void setSelfApproval(bool value) {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Test School',
        gradeLevels: const ['Grade 4', 'Grade 5', 'Grade 6'],
        sections: const ['A', 'B'],
        allowSelfApproval: value,
      ),
    ]);
  }

  AdminStudentRecord seedStudent({
    String id = 'STU-1',
    String grade = 'Grade 5',
    String className = 'Grade 5A',
  }) {
    final student = AdminStudentRecord(
      studentId: id,
      fullName: 'Abebe Kebede',
      grade: grade,
      className: className,
      schoolId: schoolId,
      dateOfBirth: DateTime(2014, 1, 1),
    );
    StudentRegistryService.instance.applyPersistedStudents(
      [student],
      replace: true,
    );
    return student;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setSelfApproval(false);
    TransferWorkflowService.instance.applyPersistedData(requests: []);
    StudentRegistryService.instance.applyPersistedStudents(
      const [],
      replace: true,
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  group('Internal transfer workflow', () {
    test('registrar creates, Vice Principal approves and placement updates',
        () async {
      seedStudent();
      signIn('registrar', AuthService.roleTeacher, [StaffRoles.registrar]);
      expect(
        await TransferWorkflowService.instance.createInternalTransfer(
          studentId: 'STU-1',
          toGrade: 'Grade 5',
          toSection: 'B',
        ),
        isNull,
      );
      final request =
          TransferWorkflowService.instance.requestsSnapshot().first;
      expect(request.status, TransferRequestStatus.pending);
      expect(request.toClassName, 'Grade 5B');

      // Registrar cannot approve.
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        'not_allowed',
      );

      // EDUABA allocation: Section Director requests, VP approves.
      signIn('sd', AuthService.roleTeacher, [StaffRoles.sectionDirector]);
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        'not_allowed',
      );

      signIn('vp', AuthService.roleTeacher, [StaffRoles.vicePresident]);
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        isNull,
      );
      expect(request.status, TransferRequestStatus.approved);

      final student = StudentRegistryService.instance.lookupById('STU-1');
      expect(student?.className, 'Grade 5B');
      expect(student?.lifecycleStatus, StudentLifecycleStatus.active);
    });

    test('self-approval blocked then allowed when school enables it', () async {
      seedStudent();
      signIn('full', AuthService.roleTeacher, [StaffRoles.fullAccess]);
      await TransferWorkflowService.instance.createInternalTransfer(
        studentId: 'STU-1',
        toGrade: 'Grade 5',
        toSection: 'B',
      );
      final request =
          TransferWorkflowService.instance.requestsSnapshot().first;
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        'self_approval_blocked',
      );
      setSelfApproval(true);
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        isNull,
      );
    });

    test('owner auto-path: create then approve succeeds (admin bypass)',
        () async {
      seedStudent();
      signIn('owner', AuthService.roleAdmin, const []);
      await TransferWorkflowService.instance.createInternalTransfer(
        studentId: 'STU-1',
        toGrade: 'Grade 6',
        toSection: 'A',
        target: InternalTransferTarget.grade,
      );
      final request =
          TransferWorkflowService.instance.requestsSnapshot().first;
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        isNull,
      );
      expect(
        StudentRegistryService.instance.lookupById('STU-1')?.grade,
        'Grade 6',
      );
    });
  });

  group('External transfer workflow', () {
    test('registrar creates, only owner can approve → lifecycle transferred',
        () async {
      seedStudent();
      signIn('registrar', AuthService.roleTeacher, [StaffRoles.registrar]);
      expect(
        await TransferWorkflowService.instance.createExternalTransfer(
          studentId: 'STU-1',
          outcome: ExternalTransferOutcome.transferred,
          reason: 'Moving to Addis',
        ),
        isNull,
      );
      final request =
          TransferWorkflowService.instance.requestsSnapshot().first;

      signIn('academic', AuthService.roleTeacher, [StaffRoles.academicAdmin]);
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        'not_allowed',
      );

      signIn('owner', AuthService.roleAdmin, const []);
      expect(
        await TransferWorkflowService.instance.approveTransfer(request.id),
        isNull,
      );
      final student =
          StudentRegistryService.instance.lookupAnyById('STU-1');
      expect(student?.lifecycleStatus, StudentLifecycleStatus.transferred);
      expect(student?.isActive, isFalse);
      expect(StudentRegistryService.instance.lookupById('STU-1'), isNull);
    });

    test('leave outcome sets lifecycle to left', () async {
      seedStudent(id: 'STU-2');
      signIn('owner', AuthService.roleAdmin, const []);
      await TransferWorkflowService.instance.createExternalTransfer(
        studentId: 'STU-2',
        outcome: ExternalTransferOutcome.left,
        reason: 'Family relocated',
      );
      final request =
          TransferWorkflowService.instance.requestsSnapshot().first;
      await TransferWorkflowService.instance.approveTransfer(request.id);
      expect(
        StudentRegistryService.instance
            .lookupAnyById('STU-2')
            ?.lifecycleStatus,
        StudentLifecycleStatus.left,
      );
    });
  });

  group('Promotion', () {
    test('promoteClass moves every student up a grade', () async {
      StudentRegistryService.instance.applyPersistedStudents([
        AdminStudentRecord(
          studentId: 'STU-A',
          fullName: 'A',
          grade: 'Grade 5',
          className: 'Grade 5A',
          schoolId: schoolId,
          dateOfBirth: DateTime(2014, 1, 1),
        ),
        AdminStudentRecord(
          studentId: 'STU-B',
          fullName: 'B',
          grade: 'Grade 5',
          className: 'Grade 5A',
          schoolId: schoolId,
          dateOfBirth: DateTime(2014, 2, 1),
        ),
      ], replace: true);
      // Ensure destination section exists for TransferService.
      await ClassStructureService.instance
          .ensureSectionForGrade('Grade 6', 'A');

      signIn('registrar', AuthService.roleTeacher, [StaffRoles.registrar]);
      final result = await TransferWorkflowService.instance.promoteClass(
        fromClassName: 'Grade 5A',
        toGrade: 'Grade 6',
        toSection: 'A',
      );
      expect(result.error, isNull);
      expect(result.count, 2);
      expect(
        StudentRegistryService.instance.lookupById('STU-A')?.className,
        'Grade 6A',
      );
      expect(
        StudentRegistryService.instance.lookupById('STU-B')?.className,
        'Grade 6A',
      );
    });

    test('graduate marks the whole class as graduated', () async {
      seedStudent(id: 'STU-G', grade: 'Grade 6', className: 'Grade 6A');
      signIn('registrar', AuthService.roleTeacher, [StaffRoles.registrar]);
      final result = await TransferWorkflowService.instance.promoteClass(
        fromClassName: 'Grade 6A',
        graduate: true,
      );
      expect(result.count, 1);
      expect(
        StudentRegistryService.instance
            .lookupAnyById('STU-G')
            ?.lifecycleStatus,
        StudentLifecycleStatus.graduated,
      );
    });

    test('nextGradeLabel walks the school grade list', () {
      expect(
        TransferWorkflowService.nextGradeLabel(
          'Grade 5',
          const ['Grade 4', 'Grade 5', 'Grade 6'],
        ),
        'Grade 6',
      );
      expect(
        TransferWorkflowService.nextGradeLabel(
          'Grade 6',
          const ['Grade 4', 'Grade 5', 'Grade 6'],
        ),
        isNull,
      );
    });
  });

  group('Model round-trips', () {
    test('lifecycle parses from legacy isActive', () {
      expect(
        StudentLifecycleStatusX.parse(null, isActiveFallback: true),
        StudentLifecycleStatus.active,
      );
      expect(
        StudentLifecycleStatusX.parse(null, isActiveFallback: false),
        StudentLifecycleStatus.left,
      );
      expect(
        StudentLifecycleStatusX.parse('graduated'),
        StudentLifecycleStatus.graduated,
      );
    });

    test('transfer request survives toMap/fromMap', () {
      final request = TransferRequest(
        id: 'tr-1',
        kind: TransferRequestKind.internal,
        studentId: 'STU-1',
        studentName: 'Abebe',
        fromGrade: 'Grade 5',
        fromClassName: 'Grade 5A',
        fromCampus: 'Main Campus',
        toGrade: 'Grade 5',
        toClassName: 'Grade 5B',
        toCampus: 'Main Campus',
        internalTarget: InternalTransferTarget.section,
        reason: 'Balance sections',
        requestedBy: 'registrar',
        requestedByName: 'Registrar',
        createdAt: DateTime(2026, 7, 28),
        schoolId: schoolId,
      );
      final restored = TransferRequest.fromMap(request.toMap());
      expect(restored.toClassName, 'Grade 5B');
      expect(restored.kind, TransferRequestKind.internal);
      expect(restored.status, TransferRequestStatus.pending);
    });
  });
}
