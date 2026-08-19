import 'package:flutter_test/flutter_test.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_dashboard_modules.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

void main() {
  group('Permission catalog', () {
    test('every template permission exists in the catalog', () {
      for (final role in StaffRoles.templates) {
        for (final perm in role.permissions) {
          expect(
            SchoolPermissions.all.contains(perm),
            isTrue,
            reason: 'Role ${role.key} references unknown permission $perm',
          );
        }
      }
    });

    test('full access holds every permission and is owner-only', () {
      final fullAccess = StaffRoles.lookup(StaffRoles.fullAccess)!;
      expect(fullAccess.permissions, equals(SchoolPermissions.all));
      expect(fullAccess.ownerOnly, isTrue);
      expect(
        StaffRoles.templates.where((r) => r.ownerOnly).map((r) => r.key),
        equals([StaffRoles.fullAccess]),
      );
    });

    test('built-in school roles from product flow are defined', () {
      expect(
        StaffRoles.byKey.keys.toSet(),
        containsAll({
          StaffRoles.fullAccess,
          StaffRoles.vicePresident,
          StaffRoles.sectionDirector,
          StaffRoles.studentAffairs,
          StaffRoles.registrar,
          StaffRoles.accountant,
          StaffRoles.humanResource,
          StaffRoles.librarian,
          StaffRoles.procurement,
          StaffRoles.storekeeper,
          StaffRoles.transportAdmin,
          // Legacy aliases still resolve:
          StaffRoles.academicAdmin,
          StaffRoles.hrAdmin,
          StaffRoles.finance,
        }),
      );
    });

    test('legacy role keys alias to the new catalog', () {
      expect(
        StaffRoles.lookup(StaffRoles.academicAdmin)?.key,
        StaffRoles.sectionDirector,
      );
      expect(
        StaffRoles.lookup(StaffRoles.hrAdmin)?.key,
        StaffRoles.humanResource,
      );
      expect(
        StaffRoles.lookup(StaffRoles.finance)?.key,
        StaffRoles.accountant,
      );
    });

    test('every staff role includes the shared baseline', () {
      final baseline = StaffDashboardModules.alwaysOnPermissions();
      for (final role in StaffRoles.templates) {
        if (role.ownerOnly) continue;
        for (final perm in baseline) {
          expect(
            role.permissions.contains(perm),
            isTrue,
            reason: '${role.key} missing baseline $perm',
          );
        }
      }
    });

    test('multi-role users combine permissions (Ahmed Ali example)', () {
      final combined = StaffRoles.permissionsForRoles([
        StaffRoles.procurement,
        StaffRoles.storekeeper,
        StaffRoles.transportAdmin,
      ]);
      expect(combined, contains(SchoolPermissions.createPurchaseRequests));
      expect(combined, contains(SchoolPermissions.manageSuppliers));
      expect(combined, contains(SchoolPermissions.issueStock));
      expect(combined, contains(SchoolPermissions.receiveStock));
      expect(combined, contains(SchoolPermissions.manageBuses));
      // EDUABA: Transport Head is the parents' transport-office contact.
      expect(combined, contains(SchoolPermissions.accessSupport));
      expect(
        combined,
        isNot(contains(SchoolPermissions.manageStaffAccounts)),
      );
      expect(combined, isNot(contains(SchoolPermissions.approveGrades)));
    });

    test('separation of duties: procurement vs storekeeper', () {
      final procurement =
          StaffRoles.lookup(StaffRoles.procurement)!.permissions;
      final storekeeper =
          StaffRoles.lookup(StaffRoles.storekeeper)!.permissions;
      expect(procurement, isNot(contains(SchoolPermissions.issueStock)));
      expect(procurement, isNot(contains(SchoolPermissions.receiveStock)));
      expect(
        storekeeper,
        isNot(contains(SchoolPermissions.approveIssueRequests)),
      );
      expect(
        storekeeper,
        isNot(contains(SchoolPermissions.createPurchaseRequests)),
      );
    });

    test('vice president has oversight plus communications and library', () {
      final vp = StaffRoles.lookup(StaffRoles.vicePresident)!.permissions;
      expect(vp, contains(SchoolPermissions.approveTransfers));
      expect(vp, contains(SchoolPermissions.approvePurchaseRequests));
      expect(vp, contains(SchoolPermissions.sendAnnouncements));
      expect(vp, contains(SchoolPermissions.manageLearningMaterials));
      expect(vp, contains(SchoolPermissions.manageMaterialAccess));
      expect(vp, contains(SchoolPermissions.accessSupport));
      expect(vp, contains(SchoolPermissions.messageParents));
      expect(vp, isNot(contains(SchoolPermissions.manageStudents)));
      expect(vp, isNot(contains(SchoolPermissions.manageFees)));
    });

    test('unknown role keys are ignored', () {
      expect(StaffRoles.permissionsForRoles(['nonsense', '']), isEmpty);
      expect(StaffRoles.lookup('does_not_exist'), isNull);
    });
  });

  group('AuthService permission checks', () {
    tearDown(() {
      AuthService.currentUser = null;
    });

    RegisteredUser makeUser(String roleKey, List<String> staffRoles) =>
        RegisteredUser(
          username: 'rbac.test',
          password: 'x',
          roleKey: roleKey,
          schoolId: 'TB-001',
          staffRoles: staffRoles,
        );

    test('logged out: no permissions', () {
      AuthService.currentUser = null;
      expect(AuthService.hasPermission(SchoolPermissions.viewStudents), isFalse);
      expect(AuthService.currentPermissions, isEmpty);
    });

    test('school owner (admin) implicitly holds everything', () {
      AuthService.currentUser = makeUser(AuthService.roleAdmin, const []);
      expect(AuthService.hasPermission(SchoolPermissions.issueStock), isTrue);
      expect(AuthService.currentPermissions, equals(SchoolPermissions.all));
      expect(AuthService.canAssignFullAccess, isTrue);
      expect(AuthService.canAssignStaffRoles, isTrue);
    });

    test('full access staff member holds everything but cannot grant it', () {
      AuthService.currentUser =
          makeUser(AuthService.roleTeacher, [StaffRoles.fullAccess]);
      expect(AuthService.currentPermissions, equals(SchoolPermissions.all));
      expect(AuthService.canAssignFullAccess, isFalse);
      expect(AuthService.canAssignStaffRoles, isTrue);
    });

    test('single-role staff member is scoped to the template', () {
      AuthService.currentUser =
          makeUser(AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(AuthService.hasPermission(SchoolPermissions.issueStock), isTrue);
      expect(
        AuthService.hasPermission(SchoolPermissions.manageFees),
        isFalse,
      );
      expect(AuthService.canAssignStaffRoles, isFalse);
      expect(
        AuthService.hasAnyPermission([
          SchoolPermissions.manageFees,
          SchoolPermissions.viewInventory,
        ]),
        isTrue,
      );
    });

    test('plain teacher without staff roles has no staff permissions', () {
      AuthService.currentUser = makeUser(AuthService.roleTeacher, const []);
      expect(AuthService.currentPermissions, isEmpty);
      expect(AuthService.canAssignStaffRoles, isFalse);
      expect(
        AuthService.hasPermission(SchoolPermissions.viewAllSchoolData),
        isFalse,
      );
    });

    test('principal can see all school data; classroom roles cannot', () {
      expect(
        StaffRoles.lookup(StaffRoles.principal)!.permissions,
        contains(SchoolPermissions.viewAllSchoolData),
      );
      expect(
        StaffRoles.lookup(StaffRoles.staffs)!.permissions,
        isNot(contains(SchoolPermissions.viewAllSchoolData)),
      );
      expect(
        StaffRoles.lookup(StaffRoles.librarian)!.permissions,
        isNot(contains(SchoolPermissions.viewAllSchoolData)),
      );
    });
  });
}
