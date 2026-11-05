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

  test('titled copy of General Manager does not rename the shared template',
      () async {
    final created = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    expect(created.error, isNull);
    expect(created.roleKey, isNot(StaffRoles.generalManager));

    final titled = SchoolRoleCatalogService.instance.lookup(
      created.roleKey!,
      schoolId: schoolId,
    );
    final template = SchoolRoleCatalogService.instance.lookup(
      StaffRoles.generalManager,
      schoolId: schoolId,
    );
    expect(titled, isNotNull);
    expect(titled!.labelEn, 'CEO');
    expect(titled.basedOn, StaffRoles.generalManager);
    expect(staffRoleLabel(titled, AppLocale.instance.strings), 'CEO');
    expect(template!.labelEn, 'General Manager');
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

  test('titled role appears only for the staff member who holds it', () async {
    final created = await SchoolRoleCatalogService.instance.ensureTitledRole(
      sourceRoleKey: StaffRoles.generalManager,
      label: 'CEO',
      schoolId: schoolId,
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Belen CEO',
      email: 'belen.ceo@school.test',
      phone: '0911000003',
      assignedClass: '',
      roles: const [],
      loginUsername: 'belen.ceo',
      staffRoles: [created.roleKey!],
    );
    TeacherRegistryService.instance.addTeacher(
      schoolId: schoolId,
      fullName: 'Other Manager',
      email: 'other@school.test',
      phone: '0911000002',
      assignedClass: '',
      roles: const [],
      loginUsername: 'other.gm',
      staffRoles: const [StaffRoles.generalManager],
    );

    final staff = InstitutionService.instance.staffDirectory(schoolId);
    final belen = staff.firstWhere((m) => m.name == 'Belen CEO');
    final other = staff.firstWhere((m) => m.name == 'Other Manager');
    expect(belen.kind, InstitutionStaffKind.admin);
    expect(belen.title, 'CEO');
    expect(other.title, 'General Manager');
  });
}
