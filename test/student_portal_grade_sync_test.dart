import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_account_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'GRADE-SYNC';

  void setMinimum(int grade, {bool enabled = true}) {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Grade Sync Academy',
        studentPortal: StudentPortalSettings(
          enabled: enabled,
          minimumGrade: grade,
          tempPasswordTemplate: 'EduAba@2026',
        ),
      ),
    ]);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    setMinimum(7);
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  AdminStudentRecord enroll(String name, String grade) {
    return StudentRegistryService.instance.addStudent(
      schoolId: schoolId,
      fullName: name,
      grade: grade,
      className: grade,
      dateOfBirth: DateTime(2014, 3, 2),
    );
  }

  test('lowering the portal grade gives logins to students already enrolled', () async {
    final younger = enroll('Lali Younger', 'Grade 5');
    final older = enroll('Sami Older', 'Grade 8');
    expect(
      await StudentAccountService.instance.createPortalAccount(
        studentId: younger.studentId,
        createdBy: 'admin',
        schoolId: schoolId,
      ),
      isNull,
    );
    expect(
      await StudentAccountService.instance.createPortalAccount(
        studentId: older.studentId,
        createdBy: 'admin',
        schoolId: schoolId,
      ),
      isNotNull,
    );

    setMinimum(5);
    final result = await StudentAccountService.instance.syncEnrolledPortalAccess(
      schoolId: schoolId,
      actor: 'admin',
    );
    expect(result.granted, 1);
    expect(result.revoked, 0);

    final withLogin = StudentRegistryService.instance.lookupById(younger.studentId)!;
    expect(withLogin.loginUsername, isNotEmpty);
    expect(withLogin.portalAccountStatus, StudentAccountStatus.active);
    AuthService.currentUser = null;
    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: withLogin.loginUsername!,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      isNull,
    );
  });

  test('raising the portal grade turns login off and lowering it turns the same login back on', () async {
    final student = enroll('Hana Grade', 'Grade 6');
    setMinimum(6);
    final created = await StudentAccountService.instance.createPortalAccount(
      studentId: student.studentId,
      createdBy: 'admin',
      schoolId: schoolId,
    );
    expect(created, isNotNull);
    final username = created!.loginUsername!;

    setMinimum(9);
    final revoked = await StudentAccountService.instance.syncEnrolledPortalAccess(
      schoolId: schoolId,
      actor: 'admin',
    );
    expect(revoked.revoked, greaterThanOrEqualTo(1));
    final blocked = StudentRegistryService.instance.lookupById(student.studentId)!;
    expect(blocked.loginUsername, username);
    expect(blocked.portalAccountStatus, StudentAccountStatus.inactive);
    AuthService.currentUser = null;
    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: username,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      'account_inactive',
    );

    setMinimum(6);
    final restored = await StudentAccountService.instance.syncEnrolledPortalAccess(
      schoolId: schoolId,
      actor: 'admin',
    );
    expect(restored.restored, greaterThanOrEqualTo(1));
    final back = StudentRegistryService.instance.lookupById(student.studentId)!;
    expect(back.loginUsername, username);
    expect(back.portalAccountStatus, StudentAccountStatus.active);
    AuthService.currentUser = null;
    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: username,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      isNull,
    );
  });

  test('a suspended student is not turned back on when the grade changes', () async {
    final student = enroll('Noah Hold', 'Grade 8');
    final created = await StudentAccountService.instance.createPortalAccount(
      studentId: student.studentId,
      createdBy: 'admin',
      schoolId: schoolId,
    );
    expect(created, isNotNull);
    await StudentAccountService.instance.updateAccountStatus(
      studentId: student.studentId,
      status: StudentAccountStatus.suspended,
      actor: 'admin',
    );

    setMinimum(1);
    await StudentAccountService.instance.syncEnrolledPortalAccess(
      schoolId: schoolId,
      actor: 'admin',
    );
    final held = StudentRegistryService.instance.lookupById(student.studentId)!;
    expect(held.portalAccountStatus, StudentAccountStatus.suspended);
    AuthService.currentUser = null;
    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: held.loginUsername!,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      'account_inactive',
    );
  });

  test('moving an enrolled student into the portal grade creates a login', () async {
    final student = enroll('Marta Move', 'Grade 4');
    final moved = student.copyWith(grade: 'Grade 8', className: 'Grade 8');
    final prepared = await StudentAccountService.instance.preparePortalAccess(
      moved,
      actor: 'admin',
    );
    expect(prepared.change, PortalAccessChange.granted);
    expect(prepared.student.loginUsername, isNotEmpty);
    expect(prepared.student.grade, 'Grade 8');
  });

  test('an active student below the saved grade cannot sign in', () async {
    final student = enroll('Eden Below', 'Grade 8');
    final created = await StudentAccountService.instance.createPortalAccount(
      studentId: student.studentId,
      createdBy: 'admin',
      schoolId: schoolId,
    );
    expect(created, isNotNull);
    StudentRegistryService.instance.replaceStudent(
      created!.copyWith(grade: 'Grade 4'),
    );
    setMinimum(7);
    AuthService.currentUser = null;
    expect(
      AuthService.validateLogin(
        roleKey: AuthService.roleStudent,
        username: created.loginUsername!,
        password: 'EduAba@2026',
        schoolId: schoolId,
      ),
      'portal_grade',
    );
  });
}
