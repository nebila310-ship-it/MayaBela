import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/institution_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/institution_service.dart';
import 'package:mayabela/services/rbac/school_role_catalog_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'School Owner',
    );
    SchoolRoleCatalogService.instance.resetForTests();
    SchoolRoleCatalogService.instance.putEmptyForTests(schoolId);
    InstitutionService.instance.resetForTests();
  });

  tearDown(() {
    AuthService.currentUser = null;
    SchoolRoleCatalogService.instance.resetForTests();
    InstitutionService.instance.resetForTests();
  });

  test('school can rename General Manager to CEO and staff see that title', () async {
    final err = await SchoolRoleCatalogService.instance.renameRole(
      roleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    expect(err, isNull);

    final role = SchoolRoleCatalogService.instance.lookup(
      StaffRoles.generalManager,
      schoolId: schoolId,
    );
    expect(role, isNotNull);
    expect(role!.labelEn, 'CEO');
    expect(staffRoleLabel(role, AppLocale.instance.strings), 'CEO');
    expect(
      StaffRoles.lookup(StaffRoles.generalManager)!.labelEn,
      'General Manager',
    );
  });

  test('administration staff are not labeled Teacher in the meeting directory', () {
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Belen Mulugeta',
      email: 'belen@school.test',
      phone: '0911000000',
      assignedClass: '',
      roles: const [],
      loginUsername: 'belen.gm',
      staffRoles: const [StaffRoles.generalManager],
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Sara Teacher',
      email: 'sara@school.test',
      phone: '0911000001',
      assignedClass: 'Grade 1A',
      roles: const [TeacherStaffRole.homeroomTeacher],
      loginUsername: 'sara.tch',
    );

    final staff = InstitutionService.instance.staffDirectory(schoolId);
    final belen = staff.firstWhere((m) => m.name == 'Belen Mulugeta');
    final sara = staff.firstWhere((m) => m.name == 'Sara Teacher');

    expect(belen.kind, InstitutionStaffKind.admin);
    expect(belen.title, 'General Manager');
    expect(InstitutionStaffMember.kindLabel(belen.kind), isNot('Teacher'));
    expect(sara.kind, InstitutionStaffKind.teacher);
    expect(InstitutionStaffMember.kindLabel(sara.kind), 'Teacher');
  });

  test('renamed role appears on the administration staff directory line', () async {
    await SchoolRoleCatalogService.instance.renameRole(
      roleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Belen Mulugeta',
      email: 'belen@school.test',
      phone: '0911000000',
      assignedClass: '',
      roles: const [],
      loginUsername: 'belen.gm',
      staffRoles: const [StaffRoles.generalManager],
    );

    final belen = InstitutionService.instance
        .staffDirectory(schoolId)
        .firstWhere((m) => m.name == 'Belen Mulugeta');
    expect(belen.kind, InstitutionStaffKind.admin);
    expect(belen.title, 'CEO');
    expect(
      InstitutionStaffMember.directoryLine(belen),
      startsWith('CEO · '),
    );
    expect(InstitutionStaffMember.directoryLine(belen), isNot(contains('Teacher')));
  });

  test('signed-in administration staff see the renamed job title', () async {
    await SchoolRoleCatalogService.instance.renameRole(
      roleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Belen Mulugeta',
      email: 'belen@school.test',
      phone: '0911000000',
      assignedClass: '',
      roles: const [],
      loginUsername: 'belen.gm',
      staffRoles: const [StaffRoles.generalManager],
    );
    AuthService.currentUser = RegisteredUser(
      username: 'belen.gm',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: schoolId,
      fullName: 'Belen Mulugeta',
      staffRoles: const [StaffRoles.generalManager],
    );

    expect(signedInJobTitle(AppLocale.instance.strings), 'CEO');
    expect(signedInJobTitle(AppLocale.instance.strings), isNot(contains('Teacher')));
  });
}
