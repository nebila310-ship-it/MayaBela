import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';
import 'package:mayabela/widgets/staff_role_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'FN0597';

  AdminTeacherRecord staff({
    required String id,
    required String name,
    List<String> staffRoles = const [],
    String? login,
  }) {
    return AdminTeacherRecord(
      teacherId: id,
      fullName: name,
      assignedClass: '',
      schoolId: schoolId,
      email: '${name.split(' ').first.toLowerCase()}@school.test',
      phone: '0911${id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0')}',
      roles: const [],
      loginUsername: login ?? id.toLowerCase(),
      staffRoles: staffRoles,
    );
  }

  void clearSchool() {
    for (final teacher in List<AdminTeacherRecord>.from(
      TeacherRegistryService.instance.teachersForSchool(schoolId),
    )) {
      TeacherRegistryService.instance.removeTeacher(
        teacher.teacherId,
        schoolId: schoolId,
      );
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = RegisteredUser(
      username: 'owner',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'Alebel Deribie',
    );
    AuthService.applySchoolContext(schoolId);
    clearSchool();
  });

  tearDown(() {
    AuthService.currentUser = null;
    clearSchool();
  });

  test(
    'cloud pull without staffRoles does not turn 11 staff into teachers',
    () {
      final created = [
        for (var i = 1; i <= 11; i++)
          staff(
            id: 'GM-${10000 + i}',
            name: 'Staff $i',
            staffRoles: const [StaffRoles.generalManager],
          ),
      ];
      TeacherRegistryService.instance.applyPersistedTeachers(created);

      expect(
        TeacherRegistryService.instance.visibleAdministrationStaff(
          schoolId: schoolId,
        ),
        hasLength(11),
      );
      expect(
        TeacherRegistryService.instance.visibleClassroomTeachers(
          schoolId: schoolId,
        ),
        isEmpty,
      );

      // Login pull used to replace the directory with rows that omitted roles.
      TeacherRegistryService.instance.applyPersistedTeachers([
        for (final row in created) staff(id: row.teacherId, name: row.fullName),
      ]);
      expect(
        TeacherRegistryService.instance
            .lookupById('GM-10001', schoolId: schoolId)
            ?.staffRoles,
        contains(StaffRoles.generalManager),
      );

      final stats = WebAdminStatsService.instance.load();
      expect(stats.totalAdministrationStaff, 11);
      expect(stats.totalTeachers, 0);
    },
  );

  test(
    'GM- ids stay Administration Staff even when both copies lost roles',
    () {
      TeacherRegistryService.instance.applyPersistedTeachers([
        for (var i = 1; i <= 11; i++)
          staff(id: 'GM-${10000 + i}', name: 'Staff $i'),
      ]);

      expect(
        TeacherRegistryService.instance.restoreMissingStaffRoles(
          schoolId: schoolId,
        ),
        isTrue,
      );
      expect(
        TeacherRegistryService.instance
            .lookupById('GM-10003', schoolId: schoolId)
            ?.staffRoles,
        contains(StaffRoles.generalManager),
      );
      expect(WebAdminStatsService.instance.load().totalAdministrationStaff, 11);
      expect(WebAdminStatsService.instance.load().totalTeachers, 0);
    },
  );

  test('login account roles win over an empty directory row', () {
    TeacherRegistryService.instance.applyPersistedTeachers([
      staff(id: 'TCH-1888', name: 'Amina', login: 'amina.pri'),
    ]);
    AuthService.mergePersistedUser(
      RegisteredUser(
        username: 'amina.pri',
        password: 'x',
        roleKey: AuthService.roleTeacher,
        schoolId: schoolId,
        linkedTeacherId: 'TCH-1888',
        staffRoles: const [StaffRoles.principal],
      ),
    );

    expect(
      isAdministrationStaffRecord(
        TeacherRegistryService.instance.lookupById(
          'TCH-1888',
          schoolId: schoolId,
        )!,
      ),
      isTrue,
    );
    expect(
      TeacherRegistryService.instance.restoreMissingStaffRoles(
        schoolId: schoolId,
      ),
      isTrue,
    );
    expect(
      TeacherRegistryService.instance
          .lookupById('TCH-1888', schoolId: schoolId)
          ?.staffRoles,
      contains(StaffRoles.principal),
    );
  });

  test('classroom TCH- rows without a role stay teachers', () {
    TeacherRegistryService.instance.applyPersistedTeachers([
      staff(id: 'TCH-2001', name: 'Sara Teacher'),
    ]);
    expect(
      TeacherRegistryService.instance.visibleClassroomTeachers(
        schoolId: schoolId,
      ),
      hasLength(1),
    );
    expect(
      TeacherRegistryService.instance.visibleAdministrationStaff(
        schoolId: schoolId,
      ),
      isEmpty,
    );
  });
}
